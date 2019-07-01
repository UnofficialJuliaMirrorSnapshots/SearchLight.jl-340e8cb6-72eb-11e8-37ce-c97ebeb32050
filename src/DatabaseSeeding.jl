"""
Utility functions for seeding databases.
"""
module DatabaseSeeding

using SearchLight

export random_seeder


"""
    random_seeder(m::Module, quantity = 10, save = false)

Generic random database seeder. `m` must expose a `random()` function which returns a SearchLight instance.
If `save` the data will be persisted to the database, as configured for the current environment.
"""
function random_seeder(m::Module, quantity::Int = 10, save::Bool = true; skip_validation::Bool = true)
  Core.eval(parse("using $(m)"))

  seeds = []
  for i in 1:quantity
    item = m.random()
    push!(seeds, item)

    save && SearchLight.save!(item, skip_validation = skip_validation)
  end

  seeds
end

end
