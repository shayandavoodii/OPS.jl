using Statistics
using LinearAlgebra
include("../Tools/tools.jl");

struct RPRT
  n_assets::Int
  weights::Matrix{Float64}
  budgets::Vector{Float64}
end;

function RPRT(
  adj_close::Matrix{Float64};
  w::Int64=5,
  initial_budget::Int=1,
  theta::Float64=0.8,
  epsilon=50)
  @assert w≥2 "Window length (w) must be greater than 1"

  n_assets, n_periods = size(adj_close)
  relative_prices = adj_close[:, 2:end] ./ adj_close[:, 1:end-1]
  θ, ϵ= theta, epsilon
  ϕ = adj_close[:, 2]./adj_close[:, 1]

  # Initialize the weights
  b = zeros(n_assets, n_periods)
  last_b = ones(n_assets)/n_assets

  for t in axes(adj_close, 2)

    if t<w
      b[:, t] = last_b
      continue
    end

    last_relative_price = adj_close[:, t]./adj_close[:, t-1]

    prediction = predict_relative_price(relative_prices[:, t-w+1:t-1])

    # predicted d
    dₚ = diagm(vec(prediction))

    # predicted γ
    γₚ = θ * last_relative_price ./ (θ*last_relative_price+ϕ)

    # predicted ϕ
    ϕₚ = γₚ + (-γₚ.+1).*(ϕ./last_relative_price)

    ϕ = ϕₚ

    # Update the b
    meanϕₚ = mean(ϕₚ)

    condition = norm(ϕₚ .- meanϕₚ)^2
    if condition == 0
      λ = 0
    else
      λ = max(0., ϵ.-(ϕₚ'*b[:, t])/condition)
    end

    if λ≠0
      w_ = b[:, t] .+ (dₚ*(ϕₚ .- meanϕₚ)).*λ
    else
      w_ = b[:, t]
    end

    clamp!(w_, -1e10, 1e10)

    b[:, t] = simplex_proj(w_)
  end
  b = b./sum(b, dims=1)
  budgets = ones(n_periods)*initial_budget

  for t in axes(adj_close, 2)[1:end-1]
    budgets[t+1] = budgets[t] * sum(relative_prices[:, t] .* b[:, t])
  end

  RPRT(n_assets, b, budgets)
end;

function predict_relative_price(relative_price::Matrix{Float64})
  mean(relative_price, dims=2)./relative_price[:, end]
end;
