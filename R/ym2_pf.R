#' YM2 Particle Filter
#'
#' todo
#' 
#' @author Turner Haugen
#'
#' @param N/A
#'
#' @return A Csnippet of the particle filter
#'
#' @examples 
#' filter <- ym2_pf()
#'
#' @import pomp
#'
#' @export

ym2_pf <- function() {
  data <- loglai::unde_carbon
  
  pomp_df = 1000*as.data.frame(data$BiomassC[1075:1954])
  colnames(pomp_df) = 'BiomassC'
  pomp_df$Clabs = NA
  pomp_df$LAI = c(data$UNDE_LAI[1075:1805], rep(NA, 149))
  pomp_df$Lf = NA
  Driver_df = as.data.frame(cbind(time = 0:880, MaxT = drivers_unde$MaxT[1074:1954], MinT = drivers_unde$MinT[1074:1954],
                                  yearday = drivers_unde$yearday[1074:1954], ca = drivers_unde$ca[1074:1954],
                                  rad = drivers_unde$rad[1074:1954]))
  
  dmeas_D2 <- loglai::dmeas_D2()
  
  dprior_D2 = Csnippet("
                      double lik3;
                      double lik4;
                      double lik5;
                      double lik6;
                      double lik7;
                      double lik8;
                      double lik9;
                      double lik10;
                      double lik11;
                      double lik12;
                      lik3 = dunif(d_onset, 1.0, 365.0, give_log);
                      lik4 = dunif(d_fall, 1.0, 365.0, give_log);
                      lik5 = dunif(c_eff, 10.0, 100.0, give_log);
                      lik6 = dunif(c_lf, .125, 1.0, give_log);
                      lik7 = dunif(c_ronset, 10.0, 100.0, give_log);
                      lik8 = dunif(c_rfall, 20.0, 150.0, give_log);
                      lik9 = dunif(omega_lab, 0.0, 5.0, give_log);
                      lik10 = dunif(omega_f, 0.0, 5.0, give_log);
                      lik11 = dunif(f_lab, .01, .5, give_log);
                      lik12 = dunif(f_f, .01, .5, give_log);
                      lik = (give_log) ? lik3 + lik4 + lik5 + lik6 + lik7 + lik8 + lik9 + lik10 + lik11 + lik12 : lik3 * lik4 * lik5 * lik6 * lik7 * lik8 * lik9 * lik10 * lik11 * lik12;
                     ")
  
  Csnip_transform = Csnippet("
  T_d_onset = logit((d_onset - 1.0) / (365.0 - 1.0));
  T_d_fall = logit((d_fall - 1.0) / (365.0 - 1.0));
  T_c_eff = logit((c_eff - 10.0) / (100.0 - 10.0));
  T_c_ronset = logit((c_ronset - 10.0) / (100.0 - 10.0));
  T_c_rfall = logit((c_rfall - 20.0) / (150.0 - 20.0));
  T_c_lf = logit((c_lf - .125) / (.875));
  T_omega_lab = log(omega_lab);
  T_omega_f = log(omega_f);
  T_f_f = logit((f_f - .01)/.49);
  T_f_lab = logit((f_lab - .01)/.49);
  ")
  
  Csnip_inv = Csnippet("
  d_onset = 364 * expit(T_d_onset) + 1.0;
  d_fall = 364 * expit(T_d_fall) + 1.0;
  c_eff = 90 * expit(T_c_eff) + 10.0;
  c_ronset = 90 * expit(T_c_ronset) + 10.0;
  c_rfall = 130 * expit(T_c_rfall) + 20.0;
  c_lf = .875 * expit(T_c_lf) + .125;
  omega_lab = exp(T_omega_lab);
  omega_f = exp(T_omega_f);
  f_f = (.49) * expit(T_f_f) + 0.1;
  f_f = (.49) * expit(T_f_lab) + 0.1;
  ")
  
  filter <- pomp(data = pomp_df, times = 1:880, t0 = 0,
                 rprocess = discrete_time(Csnippet("
    double psid = -2;
    double rtot = 1;
    double trange;
    double gs;
    double pp;
    double qq = -204.6453;
    double ci;
    double e0;
    double dec;
    double mult;
    double dayl;
    double cps;
    double lat_e = 46.23391;
    double a0 = c_eff;
    double a1 = 0.0156935;
    double a2 = 4.22273;
    double a3 = 208.868;
    double a4 = 0.0453194;
    double a5 = 0.37836;
    double a6 = 7.19298;
    double a7 = 0.011136;
    double a8 = 2.1001;
    double a9 = 0.789798;
    double pi = 3.141593;
    double s = 365.25/pi;
    double G;
    double psi_f = -1.3588480 + 4.5994549 * c_lf - 9.5964931 * pow(c_lf, 2.0) + 12.1567793 * pow(c_lf, 3.0) -6.8903864 * pow(c_lf, 4.0) -0.3576296 * pow(c_lf, 5.0) + 1.3941622 * pow(c_lf, 6.0);
    double onset = pow(2/pi, .5) * (6.9088/c_ronset) * exp(-pow(sin((yearday - d_onset - .6245*c_ronset)/s) * pow(2, .5) * s / c_ronset, 2));
    double fall = ((pow(2/pi, .5) * (-log(1 - c_lf)/c_rfall) * exp(-pow((sin((yearday - d_fall + psi_f)/s) * pow(2, .5) * s / c_rfall), 2))));
    trange = .5*(MaxT - MinT);
    gs = pow(fabs(psid),(0.789798)) / (0.37836*rtot + trange);
    pp = (Cfol / lma) /gs*a0*exp(a7*(MaxT));
    ci = .5*(ca + qq - pp + pow(pow(ca+qq-pp,2) - 4*(ca*qq - pp*a2), .5 ));
    e0 = (a6*pow(Cfol/lma,2)) / (pow(Cfol/lma,2) + a8);
    dec = -23.4*cos((360*(yearday + 10)/365)*pi/180)*pi/180;
    mult = tan(lat_e*pi/180)*tan(dec);
    if (mult >= 1){
      dayl = 24;
    } else if(mult <= -1){
      dayl = 0;
    } else{
      dayl = 24*acos(-mult)/pi;
    }
    cps = e0*rad*gs*(ca - ci) / (e0*rad + gs*(ca - ci));
    G = cps*(a1*dayl + a4);
    double eps_omega = .000001;
    double mu_lab = (1 - onset) * Clab + f_lab * G;
    double mean_lab = log(mu_lab) - .5*log(1 + pow(omega_lab,2));
    double sd_lab = pow(log(1 + pow(omega_lab,2)), .5) + eps_omega;
    double mu_fol = (1 - fall)*Cfol + onset*Clab + f_f * G;
    double mean_fol = log(mu_fol) - .5*log(1 + pow(omega_f,2) + eps_omega);
    double sd_fol = pow(log(1 + pow(omega_f,2)), .5);
    Cfol = rlnorm(mean_fol, sd_fol + eps_omega);
    Clab = exp(rnorm(mean_lab, sd_lab + eps_omega));
    "), delta.t = 1),
                 statenames = c('Clab', 'Cfol'),
                 covar = covariate_table(Driver_df, times = 0:880),
                 #tcovar = 'time',
                 covarnames = c('MaxT', 'MinT', 'yearday', 'ca', 'rad'),
                 rinit = function(Clab_0, LAI_0, lma, ...){
                   c(Clab = rnorm(1, Clab_0, .03*Clab_0),
                     Cfol = rnorm(1, LAI_0*lma, .15*LAI_0*lma))
                 },
                 dmeasure = dmeas_D2,
                 dprior = dprior_D2,
                 #params = pars[c('Clab_0', 'lma', 'LAI_0', 'omega_obs_f',
                 #               'd_fall', 'c_rfall', 'c_lf', 'd_onset', 'c_ronset', 'c_eff',
                 #                'omega_f', 'omega_lab', 'f_f', 'f_lab')],
                 partrans = parameter_trans(toEst = Csnip_transform, fromEst = Csnip_inv),
                 paramnames = c('Clab_0', 'lma', 'LAI_0', 'omega_obs_f',
                                'd_fall', 'c_rfall', 'c_lf', 'd_onset', 'c_ronset', 'c_eff',
                                'omega_f', 'omega_lab', 'f_f', 'f_lab'))
  
  return(filter)
}