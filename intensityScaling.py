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

app_name = 'intensity Scaling.'
version = '1.0.0'
release_date = '2024-11-08'

def print_header():
	print('\n\n')
	print(app_name, '- version: v', version, release_date, '\n')
	print('Computational Radiology Lab (CRL)\nBoston Children\'s Hospital, and Harvard Medical School\nhttp://crl.med.harvard.edu\nAuthor: Simon Warfield')
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
parser.add_argument("--refvolume", required=True)
args = parser.parse_args()

refVolume = args.refvolume

img = sitk.ReadImage(refVolume, sitk.sitkFloat64)
arr = sitk.GetArrayFromImage(img)

# Origin
print('Origin:')
print(img.GetOrigin())

# Center of first voxel.
image_origin = img.TransformContinuousIndexToPhysicalPoint(
    [0 for index in img.GetSize()] )
print('center of first voxel is : ' + str(image_origin) )

minVal = np.min(arr)
maxVal = np.max(arr)
print('minVal : ' + str(minVal) )
print('maxVal : ' + str(maxVal) )

print('========== ALL DONE ============')

exit(0)

