# EctoMorphExample

Example app built using ecto morph.

* The JSON schemas are in `priv/ecto_morph/json_schemas/` folder which is
  configured as the path in `config/config.exs`.

* In `EctoMorphExample.Application.start_link/2`, we make a call to `EctoMorph`
  to load all json schemas into the memory as Ecto schemas.

* Final effects of this can be seen in `test/ecto_morph_example_test.exs` where
  we can see that two Ecto schema modules have been loaded using `EctoMorph`.
