using LowRankModels
import StatsBase: sample, Weights

# test truncated loss; compare with quadratic

## generate data
srand(1);
m,n,k = 300,300,3;
kfit = k+1
# variance of measurement
sigmasq = .1

# coordinates of covariates
X_real = randn(m,k)
# directions of observations
Y_real = randn(k,n)

XY = X_real*Y_real;
A = XY + sqrt(sigmasq)*randn(m,n)
lb = 0
ub = 10
A = max.(lb, min.(ub, A))

# and the model
losses = TruncatedLoss(QuadLoss(), lb, ub)
# losses = QuadLoss()
rx, ry = QuadReg(.1), QuadReg(.1);
glrm = GLRM(A,losses,rx,ry,kfit)
#scale=false, offset=false, X=randn(kfit,m), Y=randn(kfit,n));

# fit w/truncated loss
init_svd!(glrm)
@time X,Y,ch = fit!(glrm);
println("After fitting with TruncatedLoss, parameters differ from true parameters by $(vecnorm(XY - X'*Y)/sqrt(prod(size(XY)))) in RMSE\n")
Ahat = impute(glrm);
rmse = norm(A - Ahat) / sqrt(prod(size(A)))
println("Imputations with TruncatedLoss differ from true matrix values by $rmse in RMSE")

# fit w/quad loss
glrm.losses = fill(QuadLoss(), length(glrm.losses))
init_svd!(glrm)
@time X,Y,ch = fit!(glrm);
println("After fitting with QuadLoss, parameters differ from true parameters by $(vecnorm(XY - X'*Y)/sqrt(prod(size(XY)))) in RMSE\n")
Ahat = impute(glrm);
rmse = norm(A - Ahat) / sqrt(prod(size(A)))
println("Imputations with QuadLoss differ from true matrix values by $rmse in RMSE")
