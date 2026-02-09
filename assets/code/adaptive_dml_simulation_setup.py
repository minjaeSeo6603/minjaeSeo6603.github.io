import numpy as np
from sklearn.preprocessing import PolynomialFeatures
from sklearn.linear_model import LinearRegression
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import cross_val_score
from sklearn.metrics import root_mean_squared_error
from econml.dml import LinearDML
from scipy import stats
import pandas as pd
from sklearn import metrics
from numba import jit
import logging
import time

# Setting up logging
logger = logging.getLogger(__name__)
logger.propagate = False

logger.setLevel(logging.INFO)
#logger.setLevel(logging.DEBUG)

# Console handler - uncomment if you want logs to output to the console
#ch = logging.StreamHandler()
#ch.setLevel(logging.INFO)
#ch.setLevel(logging.DEBUG)

# File handler
fh = logging.FileHandler('Logs/simulation.log', mode='w')
fh.setLevel(logging.INFO)
#fh.setLevel(logging.DEBUG)

# Formatter (optional, for consistent formatting)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
#ch.setFormatter(formatter)
fh.setFormatter(formatter)

# Adding handlers to the logger
#logger.addHandler(ch)
logger.addHandler(fh)



# Need to add spline featurizer
def polynomial_treatment(treatment: np.ndarray, order: int) -> np.ndarray:
    """
    Featurize treatment into a polynomial of specified order.

    Parameters
    ----------
    treatment : array_like
        One-dimensional list or array of treatment statuses (length n).
    order : int
        Order of the polynomial featurization.

    Returns
    -------
    np.ndarray
        Array of featurized treatments.
    """
    treatment_array = np.array(treatment)
    featurized_treatment = np.vstack([np.power(treatment_array, k) for k in range(1, order + 1)])
    
    return featurized_treatment.T


@jit(nopython=True)
def m_0_computation(covariates: np.ndarray, bounds: tuple, complexity: str) -> np.ndarray:
    """
    Function mapping covariates to treatment. T = m_0(W) + V from the PLR model.
    This is only the computation portion - optimized via numba.

    Parameters
    ----------
    covariates : np.ndarray
        Covariates.
    bounds : tuple
        Bounds for coefficients in the nuisance function. Defaults to (-1, 1).
    complexity : {'linear', 'polynomial'}
        Specify the complexity of the functional form. Defaults to 'linear'.

    Returns
    -------
    np.ndarray
        Array of length n.
    """
    k = covariates.shape[1]
    coeffs = np.random.uniform(low=bounds[0], high=bounds[1], size=k)
    
    if complexity == 'linear':
        return covariates.dot(coeffs)
    elif complexity == 'polynomial':
        covariates_poly = np.copy(covariates)
        orders = np.random.randint(1, 4, k)
        covariates_poly = np.power(covariates_poly, orders)
        return covariates_poly.dot(coeffs)
    else:
        raise ValueError("Invalid complexity level")

def m_0(covariates: np.ndarray, bounds: list = [-1, 1], complexity: str = 'linear') -> np.ndarray:
    """
    Function mapping covariates to treatment. T = m_0(W) + V from the PLR model.

    Parameters
    ----------
    covariates : np.ndarray
        Covariates.
    bounds : list, optional
        Bounds for coefficients in the nuisance function. Defaults to [-1, 1].
    complexity : {'linear', 'polynomial'}, optional
        Specify the complexity of the functional form. Defaults to 'linear'.

    Returns
    -------
    np.ndarray
        Array of length n.
    """
    logger.debug(f"Entered m_0 with parameters: covariates.shape={covariates.shape}, bounds={bounds}, complexity={complexity}")

    try:
        result =  m_0_computation(covariates, tuple(bounds), complexity)
    except ValueError as e:
        logger.warning(f"Invalid complexity level: {complexity}. Choose either 'linear' or 'polynomial'.")
        raise e
    
    logger.debug(f"m_0 result: {result}")
    return result


@jit(nopython=True)
def g_0_computation(covariates: np.ndarray, bounds: tuple, complexity: str, max_order: int) -> np.ndarray:
    """
    Numba-optimized function mapping covariates to nuisance part of the outcome.
    This function performs the core computation and is optimized with Numba.

    Parameters
    ----------
    covariates : np.ndarray
        Covariates.
    bounds : tuple
        Bounds for coefficients in the nuisance function.
    complexity : {'linear', 'polynomial'}
        Specify the complexity of the functional form.
    max_order : int
        Maximum order in the polynomial nuisance function.

    Returns
    -------
    np.ndarray
        Array of length n.
    """
    k = covariates.shape[1]
    coeffs = np.random.uniform(low=bounds[0], high=bounds[1], size=k)
    
    if complexity == 'linear':
        return covariates.dot(coeffs)
    elif complexity == 'polynomial':
        covariates_poly = np.copy(covariates)
        for i in range(k):
            covariates_poly[:, i] = np.power(covariates[:, i], np.random.randint(1, max_order + 1))
        return covariates_poly.dot(coeffs)
    else:
        raise ValueError("Invalid complexity level")

    
def g_0(covariates: np.ndarray, bounds: list = [-1, 1], complexity: str = 'linear', max_order: int = 3) -> np.ndarray:
    """
    Function mapping covariates to nuisance part of the outcome.
    Y = h_0(theta_0, W) + g_0(W) + U from the PLR model.

    Parameters
    ----------
    covariates : np.ndarray
        Covariates.
    bounds : list, optional
        Bounds for coefficients in the nuisance function. Defaults to [-1, 1].
    complexity : {'linear', 'polynomial'}, optional
        Specify the complexity of the functional form. Defaults to 'linear'.
    max_order : int, optional
        Maximum order in the polynomial nuisance function. Defaults to 3.

    Returns
    -------
    np.ndarray
        Array of length n.
    """
    logger.debug(f"Entered g_0 with parameters: covariates.shape={covariates.shape}, bounds={bounds}, complexity={complexity}, max_order={max_order}")
    
    try:
        result = g_0_computation(covariates, tuple(bounds), complexity, max_order)
    except ValueError as e:
        logger.warning(f"Invalid complexity level: {complexity}. Choose either 'linear' or 'polynomial'.")
        raise e
    
    logger.debug(f"g_0 result: {result}")
    return result


@jit(nopython=True)
def compute_leverage(treat_sieve):
    """
    Compute the leverage values using the SVD or direct matrix inversion for better performance.
    """
    pseudo_inverse = np.linalg.pinv(treat_sieve.T @ treat_sieve)
    leverage = np.sum(treat_sieve * (treat_sieve @ pseudo_inverse), axis=1)
    return leverage


def single_mc_iteration(W: np.ndarray, T: np.ndarray, Ty: np.ndarray, var_epsilon: float, max_complexity: int, 
                        support_Y: np.ndarray, tune_folds: int = 3, tune_metric: str = 'neg_mean_squared_error',
                        g_bounds: list = [-1, 1], g_complexity: str = 'polynomial', g_max_order: int = 3, 
                        stability: int = 1) -> list:
    """
    Single iteration of Monte Carlo Simulation.

    Parameters
    ----------
    W : np.ndarray
        Covariates.
    T : np.ndarray
        Base treatment statuses.
    Ty : np.ndarray
        Transformed treatment (input to second stage).
    var_epsilon : float
        Variance of epsilon (second stage structural errors).
    max_complexity : int
        Maximum model complexity. For polynomials, this is the highest order in the sieve space.
    support_Y : np.ndarray
        Support indices for Y.
    tune_folds : int, optional
        Number of folds for model tuning. Defaults to 3.
    tune_metric : str, optional
        Metric for tuning the model. Defaults to 'neg_mean_squared_error'.
    g_bounds : list, optional
        Bounds for coefficients in the nuisance function g_0(). Defaults to [-1, 1].
    g_complexity : {'linear', 'polynomial'}, optional
        Specify the complexity of the functional form for g_0(). Defaults to 'polynomial'.
    g_max_order : int, optional
        Maximum order in the polynomial nuisance function if `complexity='polynomial'`. Defaults to 3.
    stability : int, optional
        Number of times to partition the sample for methods that use sample splitting. Defaults to 1.

    Returns
    -------
    list
        List of model outputs and metrics.
    """
    start_time = time.time()
    logger.info("Starting single_mc_iteration")
    logger.debug(f"Parameters: W.shape={W.shape}, T.shape={T.shape}, Ty.shape={Ty.shape}, "
                 f"var_epsilon={var_epsilon}, max_complexity={max_complexity}, support_Y={support_Y}, "
                 f"tune_folds={tune_folds}, tune_metric={tune_metric}, g_bounds={g_bounds}, "
                 f"g_complexity={g_complexity}, g_max_order={g_max_order}, stability={stability}")

    n = W.shape[0]
    
    try:
        # Generate outcomes
        eps_y = np.random.normal(0, np.sqrt(var_epsilon), size=n)
        eps_y2 = np.random.binomial(1, 0.1, n) * np.random.normal(0, 3 * np.sqrt(var_epsilon), size=n)  # OUTLIERS
        Y = Ty + g_0(W[:, support_Y], bounds=g_bounds, complexity=g_complexity, max_order=g_max_order) + eps_y + eps_y2
        logger.debug("Generated outcomes Y")
        
        # Initialize metrics
        model_out = 0  # placeholder for indices to work, need to lower memory usage
        cv_metrics = {f'order_{lmbd}': {} for lmbd in range(1, max_complexity + 1)}
        non_cv_metrics = {}
        
        # Precompute some common values outside the loop
        T_reshaped = T.reshape(-1, 1)
        
        for lmbd in range(1, max_complexity + 1):
            logger.debug(f"Starting loop iteration for complexity order {lmbd}")
            
            # Featurizing treatment
            poly = PolynomialFeatures(lmbd)
            treat_sieve = np.ascontiguousarray(poly.fit_transform(T_reshaped)[:, 1:])
            
            # Defining model
            est = LinearDML(model_y=RandomForestRegressor(),
                            model_t=RandomForestRegressor(),
                            linear_first_stages=False,
                            cv=tune_folds)
            
            # Fitting the DML model (to get residuals)
            est.fit(Y=Y.ravel(), T=treat_sieve, X=None, W=W, cache_values=True)
            logger.debug(f"Fitted DML model for complexity order {lmbd}")
            
            # First stage residuals
            Y_res, T_res = est.residuals_[0], est.residuals_[1]
            Y_res = Y_res.reshape(-1, 1)
            #logger.debug(f"T_res shape {np.shape(T_res)}")
            #logger.debug(f"Y_res shape {np.shape(Y_res)}")
            
            # Cross-validation over the first stage residuals
            stage2_ols = LinearRegression()
            scores = {
                'MSE': cross_val_score(stage2_ols, T_res, Y_res, cv=tune_folds, scoring=tune_metric),
                'MAE': cross_val_score(stage2_ols, T_res, Y_res, cv=tune_folds, scoring='neg_median_absolute_error'),
                'R2': cross_val_score(stage2_ols, T_res, Y_res, cv=tune_folds, scoring='r2'),
                'rMSE': cross_val_score(stage2_ols, T_res, Y_res, cv=tune_folds, 
                                        scoring=metrics.make_scorer(root_mean_squared_error))
            }
            
            for key, value in scores.items():
                cv_metrics[f'order_{lmbd}'][key] = value.mean()
            
            # Non-CV metrics
            resid = Y_res - T_res.dot(est.intercept_)
            
            aic = n * np.log(np.mean(resid ** 2)) + 2 * lmbd
            aic_c = aic + 2 * lmbd * (lmbd + 1) / (n - lmbd - 1)
            bic = n * np.log(np.mean(resid ** 2)) + np.log(n) * lmbd
            
            # Compute leverage using Numba-optimized function
            leverage = compute_leverage(treat_sieve)
            msfe = np.mean(np.divide(resid ** 2, (1 - leverage) ** 2))
            non_cv_metrics[f'order_{lmbd}'] = [aic, aic_c, bic, msfe]
            
            logger.debug(f"Computed metrics for complexity order {lmbd}")
        
    except Exception as e:
        logger.error(f"Error in single_mc_iteration: {e}")
        raise e
    
    end_time = time.time()
    logger.info(f"single_mc_iteration completed in {end_time - start_time:.4f} seconds")
    
    return [model_out, cv_metrics, non_cv_metrics]




def parallelize_sim(s_eps_y: float, s_eps_t: float, Wf: np.ndarray, theta_0f: np.ndarray, 
                    support_T: np.ndarray, support_Y: np.ndarray, treat_order: int, num_iterations: int) -> list:
    """
    Function wrapper for parallelizing Monte Carlo simulations, testing variances and metric performance.

    Parameters
    ----------
    s_eps_y : float
        Variance of the structural error for the second stage Y.
    s_eps_t : float
        Variance of the structural error for the first stage T.
    Wf : np.ndarray
        Covariates.
    theta_0f : np.ndarray
        True parameters.
    support_T : np.ndarray
        Support indices for T from W.
    treat_order : int
        Polynomial order for treatment.
    num_iterations : int
        Number of iterations for each variance combination.

    Returns
    -------
    list
        List containing the variance combinations and model selection results.
    """
    n = Wf.shape[0]
    model_selection = pd.DataFrame(columns=['CV_MSE', 'CV_MAE', 'CV_R2', 'CV_rMSE', 
                                            'AIC', 'cAIC', 'BIC', 'MSFE',
                                            'Ens_All', 'Ens_CV', 'Ens_IC'])

    # Determine the interval at which to log progress
    log_interval = max(1, num_iterations // 10)

    for s in range(num_iterations):
        if (s + 1) % log_interval == 0 or s == num_iterations - 1:
            logger.info(f"Starting iteration {s + 1} of {num_iterations}")
        
        eps_t = np.random.normal(0, np.sqrt(s_eps_t), size=n)
        eps_t2 = np.random.binomial(1, 0.1, n) * np.random.normal(0, 3 * np.sqrt(s_eps_t), size=n)  # OUTLIERS 
        T = m_0(Wf[:, support_T], complexity='polynomial') + eps_t + eps_t2
        T_h_0 = polynomial_treatment(T, order=treat_order)

        # Fitting the model
        naive = single_mc_iteration(Wf, T, T_h_0.dot(theta_0f), var_epsilon=s_eps_y, max_complexity=6,
                                    support_Y = support_Y)

        # Model Selection
        mse = np.abs([naive[1][f'order_{i}']['MSE'] for i in range(1, 7)])
        min_m_mse = np.argmin(mse) + 1

        mae = np.abs([naive[1][f'order_{i}']['MAE'] for i in range(1, 7)])
        min_m_mae = np.argmin(mae) + 1

        r2 = np.abs([naive[1][f'order_{i}']['R2'] for i in range(1, 7)])
        min_m_r2 = np.argmin(np.abs(1 - r2)) + 1

        rmse = np.abs([naive[1][f'order_{i}']['rMSE'] for i in range(1, 7)])
        min_m_rmse = np.argmin(rmse) + 1

        metric_AIC = [naive[2][f'order_{i}'][0] for i in range(1, 7)]
        min_m_AIC = np.argmin(metric_AIC) + 1

        metric_cAIC = [naive[2][f'order_{i}'][1] for i in range(1, 7)]
        min_m_cAIC = np.argmin(metric_cAIC) + 1

        metric_BIC = [naive[2][f'order_{i}'][2] for i in range(1, 7)]
        min_m_BIC = np.argmin(metric_BIC) + 1

        metric_MSFE = [naive[2][f'order_{i}'][3] for i in range(1, 7)]
        min_m_MSFE = np.argmin(metric_MSFE) + 1
        
        # Ensemble tuning
        modal_model_all = stats.mode(np.array([min_m_mse, min_m_mae, min_m_r2, min_m_rmse, 
                                               min_m_AIC, min_m_cAIC, min_m_BIC, min_m_MSFE]))[0]#[0]
        modal_model_cv = stats.mode(np.array([min_m_mse, min_m_mae, min_m_r2, min_m_rmse]))[0]#[0]
        modal_model_ic = stats.mode(np.array([min_m_AIC, min_m_BIC, min_m_MSFE]))[0]#[0]

        model_selection.loc[s] = [min_m_mse, min_m_mae, min_m_r2, min_m_rmse, 
                                  min_m_AIC, min_m_cAIC, min_m_BIC, min_m_MSFE, 
                                  modal_model_all, modal_model_cv, modal_model_ic]

    return [[s_eps_y, s_eps_t], model_selection]


