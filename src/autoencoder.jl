import Stats.sample, Base.size

export GLRM, objective, Params, FunctionArray, getindex, display, size, autoencode
# type GLRM{T,I}
# 	A::Array{T,2}
# 	obs::Array{(I,I),1}
# 	losses::Array{Loss,1}
# 	rt::Regularizer
# 	r::Regularizer
# 	k::I
# 	X::Array{T,2}
# 	Y::Array{T,2}
# end
type GLRM
	A
	obs
	losses
	rt
	r
	k
	X
	Y
end
# default initializations for obs, X, and Y
GLRM(A,obs,losses,rt,r,k) = 
	GLRM(A,obs,losses,rt,r,k,randn(size(A,1),k),randn(k,size(A,2)))
GLRM(A,losses,rt,r,k) = 
	GLRM(A,[(i,j) for i=1:size(A,1),j=1:size(A,2)][:],losses,rt,r,k)	
function objective(glrm::GLRM)
	err = 0
	Z = glrm.X * glrm.Y
	for (i,j) in glrm.obs
		err += evaluate(glrm.losses[j], Z[i,j], glrm.A[i,j])
	end
	return err #+ glrm.r(X) + glrm.rt(Y)
end

type Params
	alpha # step size
	num_rounds # maximum number of iterations
	convergence_tol # stop when decrease in objective per iteration is less than convergence_tol*length(obs)
end
Params() = Params(1,100,.01)

type FunctionArray<:AbstractArray
	f::Function
	arr::Array
end
getindex(fa::FunctionArray,idx::Integer...) = x->fa.f(x,fa.arr[idx...])
display(fa::FunctionArray) = println("FunctionArray($(fa.f),$(fa.arr))")
size(fa::FunctionArray) = size(fa.arr)

type ColumnFunctionArray<:AbstractArray
    f::Array{Function,1}
    arr::AbstractArray
end
getindex(fa::ColumnFunctionArray,idx::Integer...) = x->fa.f[idx[2]](x,fa.arr[idx...])
display(fa::ColumnFunctionArray) = println("FunctionArray($(fa.f),$(fa.arr))")
size(fa::ColumnFunctionArray) = size(fa.arr)

function sort_observations(obs,m,n)
    observed_features = [Int32[] for i=1:m]
    observed_examples = [Int32[] for j=1:n]
    for (i,j) in obs
        push!(observed_features[i],j)
        push!(observed_examples[j],i)
    end
    return observed_features, observed_examples
end

function autoencode(glrm::GLRM,params::Params=Params(),ch::ConvergenceHistory=ConvergenceHistory("glrm"))
	
	# initialization
	gradL = ColumnFunctionArray(map(grad,glrm.losses),glrm.A)
	m,n = size(gradL)
	observed_features, observed_examples = sort_observations(glrm.obs,m,n)
	X = glrm.X; Y = glrm.Y

	# scale optimization parameters
	## stopping criterion: stop when decrease in objective < tol
	tol = params.convergence_tol * length(glrm.obs)
	## ensure step size alpha = O(1/g) is apx bounded by maximum size of gradient
	N = maximum(map(length,observed_features))
	M = maximum(map(length,observed_examples))
	alpha = params.alpha / max(M,N)

	# alternating updates of X and Y
	for i=1:params.num_rounds
		# X update
		t = time()
		XY = glrm.X*glrm.Y
		for e=1:m
			# a gradient of L wrt e
			g = sum([gradL[e,f](XY[e,f])*glrm.Y[:,f:f]' for f in observed_features[e]])
			# take a proximal gradient step
			glrm.X[e,:] = prox(glrm.r)(glrm.X[e:e,:]-alpha*g,alpha)
		end
		# Y update
		XY = glrm.X*glrm.Y
		for f=1:n
			# a gradient of L wrt f
			g = sum([glrm.X[e:e,:]'*gradL[e,f](XY[e,f]) for e in observed_examples[f]])
			# take a proximal gradient step
			glrm.Y[:,f] = prox(glrm.rt)(glrm.Y[:,f:f]-alpha*g,alpha)
		end
		t = t - time()
		update!(ch, t, objective(glrm))
		# check stopping criterion
		if i>10 && ch.objective[end-1] - ch.objective[end] < tol
			break
		end
	end
	return glrm.X,glrm.Y,ch
end
function autoencode!(glrm::GLRM,params::Params=Params(),ch::ConvergenceHistory=ConvergenceHistory("glrm"))
	glrm.X, glrm.Y = autoencode(glrm,params)
end