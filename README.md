# example_vault_chef

Example cookbook using [Vault](https://www.vaultproject.io/) to store secrets.

## References

* HashiCorp Vault - [https://www.vaultproject.io](https://www.vaultproject.io)
* HashiCorp Vault AppRoles with Chef - [https://github.com/hashicorp-guides/vault-approle-chef](https://github.com/hashicorp-guides/vault-approle-chef)
* `secrets_management` helper from [Chef Magic](https://github.com/chef-davin/chef_magic)

## Components

### Libraries

#### example_vault_chef.rb

* Defines method `api_json_fetch` which is used for fetching token data from an API

### Recipes

#### default.rb

Default cookbook recipe which optionally includes example recipes if executed within Test Kitchen and attribute `node['example_vault_chef']['run_examples']` is `true`

#### example.rb

All-in-one recipe configuration which fetches data from a Vault instance using the attribute-defined `node['example_vault_chef']['vault_token_method']`.  Vault content received is used to populate files on the local filesystem, showing simple example usage.

#### example_custom_resource.rb

Example configuration recipe which uses the `secret_hashicorp_vault` Custom Resource to fetch data from a Vault instance and saves the output in local files, showing example usage.

### Resources - secret_hashicorp_vault.rb

Chef Infra Custom Resource which can be used to fetch data from a HashiCorp Vault instance.  This resource can be re-used multiple times with different properties passed, allowing for a node to fetch multiple data sets as required during a Chef Infra Client cookbook run.

Example Usage:

  ```ruby
  secret_hashicorp_vault 'my_app_secret' do
    vault_address         'https://Vault-FQDN:8200'
    vault_namespace       'my/namespace'
    vault_path            'secret/data/name'
    vault_approle         'my-app-role'
    vault_token           'vault_access_token'
    attribute_target      'my_app_secret'
    ssl_verify            true
    action                :fetch
  end

  secret_hashicorp_vault 'my_app_secret_with_token_method' do
    vault_address               'https://Vault-FQDN:8200'
    vault_namespace             'my/namespace'
    vault_path                  'secret/data/name'
    vault_approle               'my-app-role'
    vault_token_method          'from-file'
    vault_token_method_options  {'vault_token_file' => '/path/to/token/file'}
    attribute_target            'my_app_secret'
    ssl_verify                  true
    action                      :fetch
  end
  ```

The `secret_hashicorp_vault` will fetch data from a Vault instance and store the result `[:data]` to `node.run_state` under the key which holds the resource name.  In the above examples, data fetched from Vault will be stored under `node.run_state['my_app_secret']` and `node.run_state['my_app_secret_with_token_method']`.  Since this data is in `node.run_state` it will not be persisted to the `node` object but will be usable by other resources during the cookbook run.

Detailed resource documentation can be found within the resource configuration file - [secret_hashicorp_vault.rb](resources/secret_hashicorp_vault.rb)

### Data Bags

A number of data bags are saved with this repository for usage with Test Kitchen - [test/integration/data_bags](test/integration/data_bags)

* __approle_tokens__: Standard data bag which holds a vault token
* __encrypted_tokens__: Encrypted data bag which holds a vault token
* __encrypted_data_bag_keys__:  Key data for the `encrypted_tokens` data bag, used by Test Kitchen to access the `encrypted_tokens` data.

## Usage

This cookbook can be used as an example for interacting with a HashiCorp Vault instance to retrieve secret data using the AppRole method.

### Using with local development Vault instance

This repository includes mechanisms for setting up a local development Vault instance on your workstation to use with the cookbook for demo purposes.  Pre-built Rake tasks are present in the local `Rakefile`:

```plain
$ chef exec rake -T
rake local_vault_config  # Configure a running local vault instance
rake local_vault_start   # Create a local vault instance running on port 8200
```

* Install HashiCorp Vault locally - [https://www.vaultproject.io]
* Start the local `vault` instance (this is best done in a split terminal as the process stays open) using `chef exec rake local_vault_start`:

    ```plain
    $ chef exec rake local_vault_start
    ==> Vault server configuration:

                Api Address: http://0.0.0.0:8200
                        Cgo: disabled
            Cluster Address: https://0.0.0.0:8201
                Go Version: go1.16
                Listener 1: tcp (addr: "0.0.0.0:8200", cluster address: "0.0.0.0:8201", max_request_duration: "1m30s", max_request_size: "33554432", tls: "disabled")
                Log Level: TRACE
                    Mlock: supported: false, enabled: false
            Recovery Mode: false
                    Storage: inmem
                    Version: Vault v1.6.3
                Version Sha: b540be4b7ec48d0dd7512c8d8df9399d6bf84d76+CHANGES

    ==> Vault server started! Log data will stream in below:
    ```

* Configure the local `vault` instance using the rake task `local_vault_config`:

  ```plain
  $ chef exec rake local_vault_config
    Key              Value
    ---              -----
    created_time     2021-03-11T17:06:31.007421Z
    deletion_time    n/a
    destroyed        false
    version          1
    ====== Metadata ======
    Key              Value
    ---              -----
    created_time     2021-03-11T17:06:31.007421Z
    deletion_time    n/a
    destroyed        false
    version          1

    ==== Data ====
    Key     Value
    ---     -----
    key1    key1_value
    key2    key2_value
    Success! Uploaded policy: chef-policy
    Success! Enabled approle auth method at: approle/
    Success! Data written to: auth/approle/role/chef-role
    Success! Uploaded policy: chef-role-token
    Key                  Value
    ---                  -----
    token                s.c01xCqxnKcvxOcDghhHmdkkx
    token_accessor       vT3SCX3v4MHjqJlLAaHX5kCs
    token_duration       768h
    token_renewable      true
    token_policies       ["chef-role-token" "default"]
    identity_policies    []
    policies             ["chef-role-token" "default"]
    ```

* Note the `token` output from the configuration, in the above example it is `s.c01xCqxnKcvxOcDghhHmdkkx`.  This token should be saved:
  * in the `test/integration/data_bags/approle_tokens/default.json` data_bag file.
  * in the `kitchen.yml` configuration file for test suites.
  * in the encrypted data bag `encrypted_tokens`:

    ```sh
    # cd to the test/integration directory so that it finds the data_bags path
    cd test/integration
    EDITOR=vi knife data bag edit --local-mode encrypted_tokens default --secret-file ../../files/mysecretfile
    cd ../../
    ```

* Run `kitchen test`
