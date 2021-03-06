data {

  //General fixed parameters for the experiment/models
  int<lower = 1> Nsubjects;                                         //number of subjects
  int<lower = 1> Nblocks;           
  int<lower = 1> Ntrials;                                           //maximum number of trials per subject (without missing data). Used to form the subject x trials matricies. 
  int<lower = 1> Ntrials_per_subject[Nsubjects];                    //number of trials left for each subject after data omission
  int<lower = 2> Narms;                                             //number of overall alternatives
  int<lower = 2> Nraffle;                                           //number of offers per trial



  //Behavioral data:
  //each variable being a subject x trial matrix
  //the data is padded in make_standata function so that all subjects will have the same number of trials
  int<lower = 0> action[Nsubjects,Ntrials];        //index of which arm was pulled coded 1 to 4
  int<lower = 0> reward[Nsubjects,Ntrials];            //outcome of bandit arm pull
  int<lower = 0> offer1[Nsubjects,Ntrials];            //outcome of bandit arm pull
  int<lower = 0> offer2[Nsubjects,Ntrials];            //outcome of bandit arm pull
  int<lower = 0> selected_offer[Nsubjects,Ntrials];            //outcome of bandit arm pull
  int<lower = 0> first_trial_in_block[Nsubjects,Ntrials];           //coding whether a trial is the first in a block to allow for Qval rest
  int<lower = 0> fold[Nsubjects,Ntrials];           //using my block since block seems to be reserved in stan


}

transformed data{
  int<lower = 1> Nparameters=2; //number of parameters
  vector[Narms] Qvalue_initial;     // initial values for Qvalues (defined here to aviod doing this many times across iterations)
  Qvalue_initial = rep_vector(0.5, Narms);
}

parameters {
// Declare parameters vectors. the notation "aux" indicate that the values are before transformation
  
  //population level parameters 
  vector[Nparameters] mu_aux;                    //vector with the population level mean for each model parameter
  vector<lower=0>[Nparameters] sigma_aux;          //vector of random effects variance for each model parameter
  
  //individuals level
  vector[Nsubjects] alpha_individal_aux;
  vector[Nsubjects] beta_indvidial_aux;
}


transformed parameters {
//declare variables and parameters
  real  alpha[Nsubjects];
  real  beta[Nsubjects];
  
  for (subject in 1:Nsubjects) {
    alpha[subject]   = Phi_approx(mu_aux[1]  + sigma_aux[1]  * alpha_individal_aux[subject]);//
    beta[subject]    = Phi_approx(mu_aux[2] + sigma_aux[2] * beta_indvidial_aux[subject])*10 ;//
  }

}



model {
  
  // population level priors (hyper-parameters)
  mu_aux  ~ normal(0, 1);            
  sigma_aux ~ normal(0, 0.5);        

  // indvidual level priors (subjects' parameters)
  alpha_individal_aux~ normal(0, 1);
  beta_indvidial_aux ~ normal(0, 1);
 

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Likelihood function per subject per trial

  for (subject in 1:Nsubjects){
    vector[Narms] Qcard; 
    vector[Nraffle] Qoffer; 

      for (trial in 1:Ntrials_per_subject[subject]){
        if (first_trial_in_block[subject,trial] == 1) {
                        Qcard=Qvalue_initial;
        }

          Qoffer[1]=Qcard[offer1[subject,trial]];
          Qoffer[2]=Qcard[offer2[subject,trial]];

        //liklihood function
         target +=log_softmax(beta[subject] * Qoffer)[selected_offer[subject, trial]];

        //Qvalues update
        Qcard[action[subject,trial]] += alpha[subject] * (reward[subject,trial] - Qcard[action[subject,trial]]);

      } 
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
}

generated quantities {
  real  mu_alpha;
  real  mu_beta;

  //population parameters
  mu_alpha=Phi_approx(mu_aux[1]);
  mu_beta=Phi_approx(mu_aux[2])*10;

}
