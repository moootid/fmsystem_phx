# lib/fmsystem_web/controllers/changeset_json.ex
defmodule FmsystemWeb.ChangesetJSON do
  # Use the helper
  alias FmsystemWeb.ErrorHelpers

  def render("error.json", %{changeset: changeset}) do
    # Return a map of errors keyed by field name
    %{errors: ErrorHelpers.translate_errors(changeset)}
  end
end
