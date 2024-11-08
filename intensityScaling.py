#!/usr/bin/env python3

import os
import sys
import numpy as np
import argparse
import time
import logging
import json


logging.basicConfig()
log = logging.getLogger()
log.setLevel( logging.INFO )
log.setLevel( logging.DEBUG )
        
import SimpleITK as sitk
from scipy.io import loadmat
from scipy.optimize import least_squares, curve_fit, leastsq, root
from scipy.special import huber
from numpy.fft import fftn, ifftn
from tqdm import trange, tqdm
from functools import partial
from multiprocessing import Pool, Lock, cpu_count, current_process
from multiprocessing.shared_memory import SharedMemory #V3.8+ only

app_name = 'pDate: proton density and T1/T2 Estimater'
version = '0.9.5'
release_date = '2024-02-22'

def print_header():
	print('\n\n')
	print(app_name, '- version: v', version, release_date, '\n')
	print('Computational Radiology Lab (CRL)\nBoston Children\'s Hospital, and Harvard Medical School\nhttp://crl.med.harvard.edu\nAuthor: Yao Sui')
	print('\n')


print_header()

log.info(app_name + '- version: v' + version + release_date)
log.info('Computational Radiology Lab (CRL)\nBoston Children\'s Hospital, and Harvard Medical School\nhttp://crl.med.harvard.edu\nAuthor: Yao Sui')


def np_to_img(x, ref):
	img = sitk.GetImageFromArray(x)
	img.SetOrigin(ref.GetOrigin())
	img.SetSpacing(ref.GetSpacing())
	img.SetDirection(ref.GetDirection())
	return img
    

parser = argparse.ArgumentParser()
parser.add_argument('-V', '--version', action='version',
		version='%s version : v %s %s' % (app_name, version, release_date),
		help='show version')
#group = parser.add_mutually_exclusive_group()
parser.add_argument('-m', '--mapping',
        help='specify [T1] or [T2] mapping will be estimated',
        choices=['T1', 'T2'], required=True)
parser.add_argument('--TI', type=ascii,
		help='specify inverse time (TI) values, separated by comma(,)')
parser.add_argument('--TE', type=ascii,
		help='specify echo time (TE) values, separated by comma(,)')
parser.add_argument('-fa', '--flip-angle', type=ascii,
		help='specify flip angle values in DEGREES, separated by comma(,)')
args = parser.parse_args()


data_path = '/opt/pDate/data/'
out_path = '/opt/pDate/recons/'

if not os.path.isdir(out_path):
	os.mkdir(out_path)

flist = sorted([os.path.join(data_path, f)
		for f in os.listdir(data_path) if not os.path.isdir(f)])
n_imgs = len(flist)
print('found %d images:\n' % n_imgs)
print('\n'.join(flist))

log.info('found %d images:\n' % n_imgs)
log.info('\n'.join(flist))

t1_mapping = True

if args.mapping.lower() == 't1':
    if args.TI:
        TI = np.array([float(x) for x in args.TI[1:-1].split(',')])
    else:
        print('inverse time (TI) for each image is required')
        exit()
    if args.flip_angle:
        fa = np.array([float(x) / 180. * np.pi for x in args.flip_angle[1:-1].split(',')])
        if fa.shape[-1] == 1:
            fa = np.repeat(fa, TI.shape[-1])
    else:
        print('flip angle for each image is required')
        exit()
        
    if not TI.shape[-1] == fa.shape[-1]:
        print('TIs and flip angles should be the same length')
        exit()
    n_inversions = TI.shape[-1]
    if not n_imgs == n_inversions:
        print('the number of images should be equal to the number of inversions')
        exit()
    
elif args.mapping.lower() == 't2':
    if args.TE:
        np.array(TE = [float(x) for x in args.TE[1:-1].split(',')])
    else:
        print('echo time (TE) for each image is required')
        exit()
    t1_mapping = False
    n_echoes = TE.shape[-1]
    if not n_imgs == n_echoes:
        print('the number of images should be equal to the number of echoes')
        exit()
else:
    print('please specify T1 or T2 that will be estimated')
    log.warning('please specify T1 or T2 that will be estimated')


arrs = []
for fn in flist:
    img = sitk.ReadImage(fn, sitk.sitkFloat64)
    arr = sitk.GetArrayFromImage(img)
    arrs.append(arr)

imgs = np.array(arrs[0])
imgs = np.reshape(imgs, imgs.shape + (1,))

for i in range(1, len(arrs)):
    a = np.array(arrs[i])
    a = np.reshape(a, a.shape + (1,))
    imgs = np.concatenate((imgs, a), axis=-1)

tm, pd = compute_mt(imgs, TI, fa)

sitk.WriteImage(np_to_img(pd, img), os.path.join(out_path, 'pd.nrrd'))
sitk.WriteImage(np_to_img(tm, img), os.path.join(out_path + 'tm.nrrd'))

print('========== ALL DONE ============')
