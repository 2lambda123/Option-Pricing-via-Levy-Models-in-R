###########################################################################
# Pricing European Put Options Through Simulating Levy Processes 
# Pseudocode implemented from Professor Liming Feng's Paper (pg. 17)
#
# Created by Joseph Loss on 12/17/2018
# Additional Recognition: Yuchen Duan (UIUC MSFE) and Daniel Liberman (UIC Finance)
#
# Algorithm 1: Simulating a Normal Inverse Gaussian process through a Brownian subordination
#
###########################################################################

# Input Parameters --------------------------------------------------------
# parameters taken from Feng Paper pg. 22-23
alpha = 15;                       
beta = -5; 
delta = 0.5; 
r = 0.05; 
q = 0.02; 
s0 = 100; 
K = s0; 
T = 0.5; 
N = 1.0; 

no_of_simulations= 4096*10^3;       # change number of iterations here 

# calculate mu using the formula given at the top of pg. 19
mu = r - q + delta*(sqrt(alpha^2 - (beta+1)^2) - sqrt(alpha^2 - beta^2));

# calculate gamma using the formula given in the Algorithm 1 pseudocode
gamma = sqrt(alpha^2 - beta^2)

stock_prc <- rep(0, no_of_simulations)      # create array of possible stock_prices (1 for each iteration)
put_prc <- rep(0, no_of_simulations)        # create array of possible put_prices (1 for each iteration)
call_prc <- rep(0, no_of_simulations)       # create array of possible call_prices (1 for each iteration)
euro_vanilla_put <- rep(0, no_of_simulations)    


# Box-Muller Function Template --------------------------------------------
BoxMuller <- function() {
  n = 2*N; 
  z = numeric(n);
  
  u1 = runif(n/2,0,1); 
  u2 = runif(n/2,0,1)
  
  z1 = sqrt(-2*log(u1)) * cos(2*pi*u2)      # half of normal variates
  z2 = sqrt(-2*log(u1)) * sin(2*pi*u2)      # other half
  z[seq(1, n, by=2)] = z1                   # interleave
  z[seq(2, n, by=2)] = z2                   # two halves
  
  return(z1)                                # return half
}


# Algorithm 1: Normal Inverse Gaussian ------------------------------------
for (j in 1:no_of_simulations) 
{
  # Step 1: Generate G1 and compute zeta ----------------------------------------------------
  G1 <- BoxMuller()           # generate standard normal random variable G1
  Z <- (G1^2)/gamma           # compute Z
  
  zeta <- rep(0, N)
  for (i in 1:N) 
    {
      zeta[i] = (1/gamma)*((delta*i) + (0.5*Z[i]) - sqrt((delta*i*Z[i]) + (Z[i]^2)/4))  
    }

  
  # Step 2: Generate uniform random variable U on (0,1) ----------------------------------
  Uniform <- function()       # function to generate uniform r.v. using Algorithm 1, Step 2, on pg. 17
  {
    U = runif(N,0,1)
    zt <- rep(0,N)
    for (i in 1:N)  {
      if (U[i] < (delta)/(delta+gamma*zeta[i])) {
        zt[i] = zeta[i] 
      } else  {
        zt[i] = (delta^2) / (gamma^2 * zeta[i]) 
      }
    }
    return(zt)
  } 
  
  zt = Uniform()          # generate zt using uniform function above  
  

  # Step 3: Generate StdNorm variable G2 -------------------------------------------------
  G2 <- BoxMuller()
  
  St <- rep(0,N)        # create empty vector for St
  Xt <- rep(0,N)        # create empty vector for Xt 
  
  for (i in 1:N)  
    {
    Xt[i] = mu*i + beta*zt[i] + sqrt(zt[i])*G2[i]     # compute Xt = mu*t + beta*zt + sqrt(zt)*G2
    St[i] = s0 * exp(Xt[i])                         # from pg 16. compute St = S0 * e^(Xt)    
    }
  
  stock_prc[j] = St[N]                                  # reassign variable, ie St = ST (stock value at maturity)
  put_prc[j] = exp(-r*T) * max(0, K - stock_prc[j])     # compute put price at maturity 
  call_prc[j] = exp(-r*T) * max(0, stock_prc[j] - K)    # compute call price at maturity


# Section 5.4, pg.19: European Vanilla Options ----------------------------
  # here, we use calculate the option value "V" using the formula given in Section 5.4.
  
  euro_vanilla_put[j] = s0 * exp(-r * T) * max(0, K/s0 - exp(log(stock_prc[j] / s0)))

  # note that the resulting output is identical 
  # to the result we generated through St = S0 * e^(Xt) above. 
  }

# END MonteCarlo Simulation -----------------------------------------------------------------------


# Average the computed prices: ---------------------------------------------------
"NIG Stock Price (t=T)"
sum(stock_prc) / no_of_simulations

nig.put.value <- sum(put_prc) / no_of_simulations
"NIG Put Value: " 
nig.put.value

euro_vanilla_put.value <- sum(euro_vanilla_put) / no_of_simulations
"European Vanilla Put Value: " 
euro_vanilla_put.value

values.table <- cbind(nig.put.value,euro_vanilla_put.value)
values.table


# RQuantLib benchmarking -----------------------------------------------------
# Use the EuropeanOption function of RQuantLib to calculate the Black-Scholes
# price of the European Put (all inputs are identical to the NIG inputs above, except volatility)
library(RQuantLib)

ql.put.value <- EuropeanOption(type = "put", underlying = 100, strike = 100,
                         dividendYield = 0.02, riskFreeRate = 0.05, maturity = 0.5, volatility = 0.2519)

put_prices<-cbind(nig.put.value, ql.put.value)

print("NIG Put Price vs Black-Scholes:")
put_prices


library(NMOF)

# NMOF Library function for PCP:
putCallParity("call",put=euro_vanilla_put.value,S=s0,X=K,tau=T,r=r,q=q)


# QuantLib Price of European Call option:
ql.call.value<-RQuantLib::EuropeanOption("c",s0,K,q,r,T,0.25)
ql.call.value

# Put-Call-Parity formula from scratch:
Call_Parity_Prc = euro_vanilla_put.value + s0*exp((-q * T)) - (K * exp(-r * T))
Call_Parity_Prc


# Put-Call-Parity formula from scratch:
Put_Parity_Prc = Call_Parity_Prc - (s0*exp((-q * T)) - (K * exp(-r * T)))
Put_Parity_Prc

Put_Parity_Table<-cbind(Put_Parity_Prc,nig.put.value,ql.put.value)
Put_Parity_Table

Call_Parity_Table<-cbind(Call_Parity_Prc,ql.call.value)
Call_Parity_Table

