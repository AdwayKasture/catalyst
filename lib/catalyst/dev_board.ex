# defmodule Catalyst.DevBoard do

#   def list_schemas() do
#     {:ok, modules} = :application.get_key(:catalyst,:modules)

#     modules
#     |> Enum.filter(fn module -> Code.loaded?(module) end)
#     |> Enum.filter(fn module -> function_exported?(module,:__schema__,1) end)

#   end

# end
