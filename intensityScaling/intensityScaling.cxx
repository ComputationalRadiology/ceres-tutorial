
#include <cmath>
#include <itkImageFileReader.h>
#include <itkImageFileWriter.h>
#include <itkAffineTransform.h>
#include <itkVersorRigid3DTransform.h>
#include <itkOtsuThresholdImageFilter.h>
#include <itkOtsuMultipleThresholdsImageFilter.h>
#include "itkImageDuplicator.h"
#include "itkShiftScaleImageFilter.h"
#include "itkClampImageFilter.h"
#include "itkImageRegionIteratorWithIndex.h"
#include <iomanip>
#include <iostream>
#include <vector>

#include "argparse/argparse.hpp"
#include <cassert>

// Include the Eigen template library for math
#include <Eigen/Core>
#include <Eigen/Dense>
#include <Eigen/LU>

typedef Eigen::Matrix<double, 3, 3, Eigen::RowMajor> MatrixType33d;

#include "quill/Backend.h"
#include "quill/Frontend.h"
#include "quill/LogMacros.h"
#include "quill/Logger.h"
#include "quill/sinks/FileSink.h"

#include "intensityScaling.h"

int intensityScaling(int argc, char *argv[])
{

  const unsigned int Dimension = 3;
  typedef float PixelType;
  typedef itk::Image< PixelType,  Dimension >   ImageType;
  typedef itk::ImageFileReader< ImageType  >  ReaderType;
  typedef itk::ImageFileWriter< ImageType  >  WriterType;
  typedef itk::AffineTransform< double, Dimension >  AffineTransformType;
  typedef itk::VersorRigid3DTransform< double >  VersorRigid3DTransformType;

  // Start the backend thread
  quill::BackendOptions backend_options;
  quill::Backend::start(backend_options);

  // Frontend
  auto file_sink = quill::Frontend::create_or_get_sink<quill::FileSink>(
    "example_file_logging.log",
    []()
    {
      quill::FileSinkConfig cfg;
      cfg.set_open_mode('w');
      cfg.set_filename_append_option(quill::FilenameAppendOption::StartDateTime);
      return cfg;
    }(),
    quill::FileEventNotifier{});

  quill::Logger* logger = quill::Frontend::create_or_get_logger(
    "root", std::move(file_sink),
    quill::PatternFormatterOptions{"%(time) [%(thread_id)] %(short_source_location:<28) "
                                          "LOG_%(log_level:<9) %(logger:<12) %(message)",
                                   "%H:%M:%S.%Qns", quill::Timezone::GmtTime});

  // set the log level of the logger to debug (default is info)
  logger->set_log_level(quill::LogLevel::Debug);

  LOG_INFO(logger, "Starting sms-mi-reg!");

  argparse::ArgumentParser program("sms-mi-reg");
  program.add_argument("referenceVolume")
      .help("The volume that is moving to be aligned to the slices.");
  program.add_argument("inputTransform")
      .help("The transform to initialize the alignment.");
  program.add_argument("outputTransformLabel")
      .help("Name phrase used in the construction of the output transform file name.");
  program.add_argument("inputSlices")
      .help("The list of file names of the fixed target slices.")
      .nargs(argparse::nargs_pattern::at_least_one); // "+". This accepts one or more file name arguments.

  try {
    program.parse_args(argc, argv);
  }
  catch (const std::runtime_error &err) {
    std::cerr << err.what() << std::endl;
    std::cerr << program;
    std::exit(1);
  }
 
  //adding new arguments
  std::string referenceVolume = program.get<std::string>("referenceVolume");
  LOG_INFO(logger, "Reference volume is {}." , referenceVolume);
  std::string transformfile = program.get<std::string>("inputTransform");
  std::string outputTransformLabel = program.get<std::string>("outputTransformLabel");
  
  std::vector<std::string> inputSliceFileNames = program.get<std::vector<std::string>>("inputSlices");
  std::cout << "Processing for " << inputSliceFileNames.size() << " input slices." << std::endl;
  LOG_INFO(logger, "Number of input file names : {}", inputSliceFileNames.size());
  for (auto i : inputSliceFileNames) {
    std::cout << "input slice file names : " << std::endl << i << std::endl;
  }

  std::string *inputTransformFile = new std::string( transformfile );
  std::string *inputRefImageFile = new std::string( referenceVolume );

  ReaderType::Pointer readerRefVol = ReaderType::New();
  readerRefVol->SetFileName( inputRefImageFile->c_str() );

  std::string * outputSliceImageFile = new std::string("scaled-outputSlice.nrrd");


  try {
    readerRefVol->Update();
  } catch ( itk::ExceptionObject & excp )
  {
    // Display error from reading the reference volume file.
    std::cerr << "Error while reading the reference volume " <<
                     (*inputRefImageFile->c_str()) << std::endl;
    std::cerr << excp << std::endl;
    std::cerr << "[FAILED]" << std::endl;
    return EXIT_FAILURE;
  }

// This example program uses a heuristic to compute a mapping from the
// signal intensity range of the input to the histogram bins.
//  
// It uses a rescale that maps the input signal intensities to the desirable 
// bin range [0, nbins - 1], save the mapping function, apply it to all the 
// slices.

// 1. Otsu threshold to find background and foreground.
// 2. Measure the mean and variance of the foreground voxels.
// 3. Determine a linear remapping based on the foreground intensities.
// 4. Ensuring valid range of [0, nbins - 1] is preserved
// 5. Apply scaling to the slices.

  /* The Otsu threshold is a binary threshold and appears inadequate for fmri,
   * so instead we use a multiple threshold Otsu filter.
   *
   * using OtsuFilterType = itk::OtsuThresholdImageFilter<ImageType, ImageType>;
  */

  using MOtsuFilterType = itk::OtsuMultipleThresholdsImageFilter<ImageType, ImageType>;
  auto motsuFilter = MOtsuFilterType::New();
  motsuFilter->SetInput( readerRefVol->GetOutput() );
  motsuFilter->SetNumberOfThresholds( 2 ); // 2 thresholds is suitable for fmri.
  motsuFilter->SetLabelOffset( 0 );
  motsuFilter->Update();

  MOtsuFilterType::ThresholdVectorType thresholds = motsuFilter->GetThresholds();

  std::cout << "Thresholds:" << std::endl;

  for (double threshold : thresholds)
  {
    std::cout << threshold << std::endl;
  }

  std::cout << std::endl;


  // Now make a duplicate of the thresholded image to hold and save.
  using DuplicatorType = itk::ImageDuplicator<ImageType>;
  auto duplicator = DuplicatorType::New();
  duplicator->SetInputImage( motsuFilter->GetOutput() );
  duplicator->Update();
  ImageType::Pointer clonedImage = duplicator->GetOutput();

  /* Not writing out the otsu thresholded image.
  std::cout << "Writing out a copy of the otsu thresholded image " <<
    " otsuThresholded.nrrd " << std::endl;

  // Already defined: using WriterType = itk::ImageFileWriter<ImageType>;
  auto writerOtsu = WriterType::New();
  writerOtsu->SetFileName( "otsuThresholded.nrrd" );
  writerOtsu->SetInput( clonedImage );

  try
  {
    writerOtsu->Update();
    // ITKv5 ? itk::WriteImage(clonedImage, "otsuThresholded.nrrd" );
  }
  catch (const itk::ExceptionObject & excp)
  {
    std::cerr << "Error: " << excp.GetDescription() << std::endl;
    return EXIT_FAILURE;
  }

  */


  // Iterate over the input image, checking the otsu threshold image, 
  // accumulating the min, max, mean and variance.
  itk::ImageRegionIteratorWithIndex<ImageType> imageIterator(
      readerRefVol->GetOutput(), 
      readerRefVol->GetOutput()->GetLargestPossibleRegion() 
      );

  double voxelValue = 0.0;
  double mean = 0.0;
  double variance = 0.0;
  double oldmean = 0.0;
  double oldvariance = 0.0;
  double stddev = 0.0;
  unsigned long int voxelCount = 0;

  // Modified to use Welford's algorithm for variance
  imageIterator.GoToBegin();
  double minValue = std::numeric_limits<double>::max();
  double maxValue = std::numeric_limits<double>::lowest();
  double M2 = 0.0;
  while (!imageIterator.IsAtEnd()) {
    double delta = 0.0;
    double delta2 = 0.0;
    ImageType::IndexType idx = imageIterator.GetIndex();
    float otsuVoxel = motsuFilter->GetOutput()->GetPixel(idx);
    if (otsuVoxel > 0) {
      voxelCount += 1;
      voxelValue = imageIterator.Get();
      if (voxelValue < minValue) minValue = voxelValue;
      if (voxelValue > maxValue) maxValue = voxelValue;
      delta = voxelValue - mean;
      mean += delta / (double)voxelCount;
      delta2 = voxelValue - mean;
      M2 += delta * delta2;
      oldmean += voxelValue;
      oldvariance += voxelValue*voxelValue;
    }
    ++imageIterator;
  }

  if (voxelCount == 0) {
    std::cerr << "Otsu filter found no foreground voxels." << std::endl;
    std::cerr << "Exiting with a fatal error." << std::endl;
    exit(2);
  }
  oldmean /= voxelCount;
  oldvariance = (oldvariance/voxelCount - oldmean*oldmean);
  stddev = std::sqrt(oldvariance);
  std::cout << "Mean: " << oldmean << ", Variance: " << oldvariance 
        << " StdDev: " << stddev << std::endl << std::flush;

  variance = M2 / (voxelCount);
  stddev = std::sqrt(variance);
  std::cout << "Welford Mean: " << mean << ", Variance: " << (variance)
        << " StdDev: " << stddev << std::endl << std::flush;
  std::cout << "minValue: " << minValue 
            << ", maxValue: " << maxValue << std::endl << std::flush;

  std::cout << "Labelled regions have been reported on." << std::endl 
    << std::flush;


  exit(0);

}
