"""
Core SearchLight configuration / settings functionality.
"""
module Configuration

using SearchLight, YAML

export is_dev, is_prod, is_test, env, cache_enabled, Settings, DEV, PROD, TEST, IN_REPL
export LOG_LEVEL_VERBOSITY_VERBOSE, LOG_LEVEL_VERBOSITY_MINIMAL

# app environments
const DEV   = "dev"
const PROD  = "prod"
const TEST  = "test"

# log levels
const LOG_LEVEL_VERBOSITY_VERBOSE = :verbose
const LOG_LEVEL_VERBOSITY_MINIMAL = :minimal

# defaults
const SEARCHLIGHT_VERSION = v"0.8.5"


"""
    is_dev()  :: Bool
    is_prod() :: Bool
    is_test() :: Bool

Set of utility functions that return whether or not the current environment is development, production or testing.

# Examples
```julia
julia> Configuration.is_dev()
true

julia> Configuration.is_prod()
false
```
"""
function is_dev()::Bool
  SearchLight.config.app_env == DEV
end
function is_prod()::Bool
  SearchLight.config.app_env == PROD
end
function is_test()::Bool
  SearchLight.config.app_env == TEST
end


"""
    env() :: String

Returns the current environment.

# Examples
```julia
julia> Configuration.env()
"dev"
```
"""
env() :: String = SearchLight.config.app_env


"""
    read_db_connection_data(db_settings_file::String) :: Dict{Any,Any}

Attempts to read the database configuration file and returns the part corresponding to the current environment as a `Dict`.
Does not check if `db_settings_file` actually exists so it can throw errors.
If the database connection information for the current environment does not exist, it returns an empty `Dict`.

# Examples
```julia
julia> Configuration.read_db_connection_data(...)
Dict{Any,Any} with 6 entries:
  "host"     => "localhost"
  "password" => "..."
  "username" => "..."
  "port"     => 5432
  "database" => "..."
  "adapter"  => "PostgreSQL"
```
"""
function read_db_connection_data(db_settings_file::String) :: Dict{String,Any}
  db_conn_data =  if endswith(db_settings_file, ".yml")
                    YAML.load(open(db_settings_file))
                  elseif endswith(db_settings_file, ".jl")
                    include(db_settings_file)
                  end

  if  haskey(db_conn_data, "env") &&
      db_conn_data["env"] != nothing
    SearchLight.config.app_env = ENV["SEARCHLIGHT_ENV"] = db_conn_data["env"]
  end

  if  haskey(db_conn_data, SearchLight.config.app_env) &&
      haskey(db_conn_data[SearchLight.config.app_env], "config") &&
      db_conn_data[SearchLight.config.app_env]["config"] != nothing &&
      isa(db_conn_data[SearchLight.config.app_env]["config"], Dict)
    for (k, v) in db_conn_data[SearchLight.config.app_env]["config"]
      setfield!(SearchLight.config, Symbol(k), ((isa(v, String) && startswith(v, ":")) ? Symbol(v[2:end]) : v) )
    end
  end

  return  if haskey(db_conn_data, SearchLight.config.app_env)
            db_conn_data[SearchLight.config.app_env]
          else
            push!(SearchLight.SEARCHLIGHT_LOG_QUEUE, ("DB configuration for $(SearchLight.config.app_env) not found", :debug))
            Dict{String,Any}()
          end
end


"""
    load_db_connection() :: Bool

Attempts to load the database configuration from file. Returns `true` if successful, otherwise `false`.
"""
function load_db_connection() :: Dict{String,Any}
  _load_db_connection()
end
function _load_db_connection() :: Dict{String,Any}
  load_db_connection_from_config()
end


function load_db_connection_from_config() :: Dict{String,Any}
  db_config_file = joinpath(SearchLight.CONFIG_PATH, SearchLight.SEARCHLIGHT_DB_CONFIG_FILE_NAME)
  isfile(db_config_file) && (return read_db_connection_data(db_config_file))

  # @warn "DB configuration file not found"
  return Dict{String,Any}()
end


function load() :: Dict{String,Any}
  SearchLight.config.db_config_settings = load_db_connection()
end


"""
    mutable struct Settings

App configuration - sets up the app's defaults. Individual options are overwritten in the corresponding environment file.
"""
mutable struct Settings
  app_env::String

  suppress_output::Bool
  output_length::Int

  db_migrations_table_name::String
  db_migrations_folder::String
  db_config_settings::Dict{String,Any}

  log_folder::String

  log_db::Bool
  log_queries::Bool
  log_level::Symbol
  log_verbosity::Symbol
  log_formatted::Bool
  log_highlight::Bool
  log_rotate::Bool


  model_relations_eagerness::Symbol

  Settings(;
            app_env       = ENV["SEARCHLIGHT_ENV"],

            suppress_output = false,
            output_length   = 10_000, # where to truncate strings in console

            db_migrations_table_name  = "schema_migrations",
            db_migrations_folder      = joinpath("db", "migrations"),
            db_config_settings        = Dict{String,Any}(),

            log_folder    = joinpath("log"),

            log_db        = false,
            log_queries   = true,
            log_level     = :debug,
            log_verbosity = LOG_LEVEL_VERBOSITY_VERBOSE,
            log_formatted = true,
            log_highlight = true,
            log_rotate    = true,

            model_relations_eagerness = :lazy
        ) =
              new(
                  app_env,
                  suppress_output, output_length,
                  db_migrations_table_name, db_migrations_folder, db_config_settings,
                  log_folder,
                  log_db, log_queries, log_level, log_verbosity, log_formatted, log_highlight, log_rotate,
                  model_relations_eagerness
                )
end

end
