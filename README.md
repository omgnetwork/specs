# Specs

TBD - Repo containing specs and integrations tests

## Setup and Run

```sh
# If there is already some elixir-omg docker running, this can make sure it is cleaned up
make clean

# Start the elixir-omg services (childchain, watcher and watcher_info) as background services

# Run all the tests
make test

# To run a specific test, see the <test_file_name> in apps/itest/test/
mix test test/itest/<test_file_name>.exs
```

## CI flow

If you made a change in repo that requires e2e test (`elixir-omg` is used as an example here):
1. Code the test and open PR in `specs` repo.
3. Edit `.gitmodules` to change the `specs` repo in `elixir-omg` to point to your `specs` PR branch.
4. Before you merge `elixir-omg` PR, change the `specs` repo back to master.
5. Merge the PR in `specs` repo.
