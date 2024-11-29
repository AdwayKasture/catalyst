alias Catalyst.Accounts

{:ok, user} =
  Accounts.register_user(%{
    username: "test_user",
    email: "user@example.com",
    password: "sample_password"
  })
