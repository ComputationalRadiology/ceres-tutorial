#include "nls_solver.h"

#include <ceres/ceres.h>
#include <glog/logging.h>

template<typename DataType>
struct Cost_T1
{
    Cost_T1(DataType px, DataType ti, DataType fa)
        : _px(px), _ti(ti), _fa(fa) { }

    template <typename T>
        bool operator()(const T* const t1, const T* const pd, T* residual) const {
            T t = T(1.1920929e-07);
            if(t1[0] > t)
                t = t1[0];
            residual[0] = pd[0] * (1. - (1. - cos(_fa)) * exp(-_ti / t)) - _px;
            //residual[0] = pd[0] * (1. - (1. - cos(_fa)) * exp(-_ti / t1[0])) - _px;
            return true;
        }

    private:
    const DataType _px; // pixel value
    const DataType _ti; // inversion time in ms
    const DataType _fa; // flip angle in radian
};

/*
template<typename T, typename DataType>
void evaluate_t1(T* t1, T* pd, const DataType* data, const int data_len)
*/
void evaluate_t1(double* t1, double* pd, const double* data, const int data_len)
{

    ceres::Problem problem;

    for (int i = 0; i < data_len; ++i)
    {
        problem.AddResidualBlock(
                new ceres::AutoDiffCostFunction<Cost_T1<double>, 1, 1, 1>(
                    new Cost_T1<double>(data[3*i], data[3*i+1], data[3*i+2])),
                    nullptr,
                    t1,
                    pd);
        //std::cout << data[3*i] << ", " << data[3*i+1] << ", " << data[3*i+2] << "\n";
        problem.SetParameterLowerBound(t1, 0, 0);
        problem.SetParameterUpperBound(t1, 0, 5000);
        problem.SetParameterLowerBound(pd, 0, 0);
        //problem.SetParameterUpperBound(pd, 0, 5000);
    }

    ceres::Solver::Options options;
    options.max_num_iterations = 50;
    options.linear_solver_type = ceres::DENSE_QR;
    //options.minimizer_progress_to_stdout = true;

    ceres::Solver::Summary summary;
    ceres::Solve(options, &problem, &summary);
    
    //std::cout << summary.BriefReport() << "\n";
}
