# vault_secret_fetch

resource_name :secret_hashicorp_vault
provides :secret_hashicorp_vault

unified_mode true

description 'Use the **secret_hashicorp_vault** resource to fetch data from a HashiCorp Vault provider using a token and optionally an approle and/or namespace.'
examples <<~DOC
  ```ruby
  # Fetch secret information from a HashiCorp Vault instance using a token and app-role inline
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

  # Fetch secret information from a HashiCorp Vault instance using the vault_token_method property, providing logic for how to obtain the token for initial Vault connectivity.
  secret_hashicorp_vault 'my_app_secret_with_token_method' do
    vault_address               'https://Vault-FQDN:8200'
    vault_namespace             'my/namespace'
    vault_path                  'secret/data/name'
    vault_approle               'my-app-role'
    vault_token_method          'token-file'
    vault_token_method_options({ 'vault_token_file' => '/path/to/token/file' })
    attribute_target            'my_app_secret'
    ssl_verify                  true
    action                      :fetch
  end
  ```
DOC

property :vault_address, String, required: true,
  description: 'Address of the target vault server, example https://Vault-FQDN.localdomain:8200'
property :vault_namespace, String,
  description: 'Vault namespace to use, if required.'
property :vault_path, String,
  description: 'Path to the secret data which should be fetched from the Vault server'
property :vault_approle, String,
  description: 'Vault app-role name to use, if required.'
property :vault_token, String,
  description: 'Vault token to use for authentication.'
property :vault_token_method, String,
  equal_to: %w(
    data-bag
    token-file
    encrypted-data-bag-from-bag
    secret-from-api
    encrypted-data-bag-from-file
  ),
  description: 'Method used to fetch the vault token if a vault_token is not specified'
property :vault_token_method_options, Hash,
  description: 'Ruby Hash of options to pass for chosen vault_token_method'
# TODO: Add Array support for attribute_target for nested hash storage
property :attribute_target, String, name_property: true,
  description: 'Target attribute to store data retrieved from vault.  Will be stored as a node.run_state attribute within the target space.
                Example:
                attribute_target "my_attr" --> node.run_state["my_attr"]
                '
property :ssl_verify, [true, false], default: true,
  description: 'Enable SSL verification of target vault_address when connecting.'

action_class do
  # see chef_magic cookbook for details on get_hashi_vault_object and other references
  #  https://github.com/chef-davin/chef_magic
  def get_hashi_vault_object(vault_path, vault_address, vault_token, vault_role = nil, vault_namespace = nil, ssl_verify = true)
    require 'vault'

    # Need to set the vault address
    Vault.address = vault_address
    # Authenticate with the token
    Vault.token = vault_token
    # Add namespace if passed (default is nil)
    Vault.namespace = vault_namespace
    # Update if passed (default is true)
    Vault.ssl_verify = ssl_verify

    if vault_role # Authenticate to Vault using the role_id
      approle_id = Vault.approle.role_id(vault_role)
      secret_id = Vault.approle.create_secret_id(vault_role).data[:secret_id]
      Vault.auth.approle(approle_id, secret_id)
    end

    # Attempt to read the secret
    secret = Vault.logical.read(vault_path)
    # Chef::Log.warn(secret)
    if secret.nil?
      raise "Could not read secret from '#{vault_address}/#{vault_path}'!"
    else
      secret
    end
  end
end

action :fetch do
  vault_approle = new_resource.vault_approle
  # Fetch the vault token to be used for authentication for fetching secrets
  vault_token = if new_resource.vault_token
                  log 'Using vault_token property'
                  new_resource.vault_token
                elsif new_resource.vault_token_method
                  log "Using vault_token_method #{new_resource.vault_token_method}"
                  case new_resource.vault_token_method
                  when 'data-bag'
                    # Fetches the token/secretid to read from Vault via data bag
                    #  In a real environment this should be an encrypted data bag or some other secure
                    #  location for obtaining this data.
                    data_bag = new_resource.vault_token_method_options['data_bag'] ||
                               raise("value is required for vault_token_method_options['data_bag']")
                    data_bag_item = new_resource.vault_token_method_options['data_bag_item'] ||
                                    raise("value is required for vault_token_method_options['data_bag_item']")
                    vault_approle = new_resource.vault_approle
                    data_bag_item(data_bag, data_bag_item)[vault_approle]['token']
                  when 'token-file'
                    # Fetches the token/secretid from a file on the filesystem of the server
                    # Mock up creating the token_file for test-kitchen only
                    vault_token_file = new_resource.vault_token_method_options['vault_token_file'] ||
                                       raise("value is required for vault_token_method_options['vault_token_file']")
                    vault_token_file_content = new_resource.vault_token_method_options['vault_token_file_content']

                    # Populate the vault_token_file during Test Kitchen, if needed
                    file vault_token_file do
                      content vault_token_file_content.to_s
                      only_if { ENV['TEST_KITCHEN'] == '1' }
                    end.run_action(:create)

                    # Reads the first line of a file specified
                    ::File.read(vault_token_file).split()[0] if ::File.exist?(vault_token_file)
                  when 'encrypted-data-bag-from-bag'
                    # Fetches the encrypted data_bag secret key from a data_bag and then uses that encryption key to read the
                    #  Vault secret token from the `encrypted_tokens` data_bag.
                    key_data_bag = new_resource.vault_token_method_options['key_data_bag'] ||
                                   raise("value is required for vault_token_method_options['key_data_bag']")
                    key_data_bag_item = new_resource.vault_token_method_options['key_data_bag_item'] ||
                                        raise("value is required for vault_token_method_options['key_data_bag_item']")
                    encrypted_data_bag = new_resource.vault_token_method_options['encrypted_data_bag'] ||
                                         raise("value is required for vault_token_method_options['encrypted_data_bag']")
                    encrypted_data_bag_item = new_resource.vault_token_method_options['encrypted_data_bag_item'] ||
                                              raise("value is required for vault_token_method_options['encrypted_data_bag_item']")
                    vault_approle = new_resource.vault_approle
                    key_content = data_bag_item(key_data_bag, key_data_bag_item)['key'].strip()
                    data_bag_item(encrypted_data_bag, encrypted_data_bag_item, key_content)[vault_approle]['token']
                  when 'encrypted-data-bag-from-file'
                    # Fetches the encrypted data_bag secret key from a local file and then uses that encryption key to read the
                    #  Vault secret token from the `encrypted_tokens` data_bag.
                    encrypted_data_bag_secret_file = new_resource.vault_token_method_options['encrypted_data_bag_secret_file'] ||
                                                     raise("value is required for vault_token_method_options['encrypted_data_bag_secret_file']")
                    encrypted_data_bag_secret_file_content = new_resource.vault_token_method_options['encrypted_data_bag_secret_file_content'] ||
                                                             raise("value is required for vault_token_method_options['encrypted_data_bag_secret_file_content']")
                    encrypted_data_bag = new_resource.vault_token_method_options['encrypted_data_bag'] ||
                                         raise("value is required for vault_token_method_options['encrypted_data_bag']")
                    encrypted_data_bag_item = new_resource.vault_token_method_options['encrypted_data_bag_item'] ||
                                              raise("value is required for vault_token_method_options['encrypted_data_bag_item']")
                    vault_approle = new_resource.vault_approle

                    # Mock up creating the token_file for test-kitchen only
                    file encrypted_data_bag_secret_file do
                      content encrypted_data_bag_secret_file_content unless encrypted_data_bag_secret_file_content.nil?
                      only_if { ENV['TEST_KITCHEN'] == '1' }
                    end.run_action(:create)

                    key_content = Chef::EncryptedDataBagItem.load_secret(encrypted_data_bag_secret_file)
                    data_bag_item(encrypted_data_bag, encrypted_data_bag_item, key_content)[vault_approle]['token']
                  when 'secret-from-api'
                    # Fetches the token/secretid to read from Vault via external API
                    #  Looks for a JSON response from API with body of {"approle-name": { "token": "tokenvalue"}}
                    api_secret_server = new_resource.vault_token_method_options['api_secret_server'] ||
                                        raise("value is required for vault_token_method_options['api_secret_server']")
                    api_data = api_json_fetch(api_secret_server.to_s)
                    vault_approle = new_resource.vault_approle

                    api_data[vault_approle]['token']
                  end # end case
                else
                  raise 'Neither vault_token or vault_token_method were specified, one must have a value to fetch secret values from Vault instance.'
                end

  raise('Unable to determine vault_token, nil value') unless vault_token

  vault_address = new_resource.vault_address
  vault_namespace = new_resource.vault_namespace
  vault_path = new_resource.vault_path
  attribute_target = new_resource.attribute_target
  ssl_verify = new_resource.ssl_verify

  log "Fetching Vault data from #{new_resource.vault_address}"

  node.run_state[attribute_target] = get_hashi_vault_object(
    vault_path,
    vault_address,
    vault_token,
    vault_approle,
    vault_namespace,
    ssl_verify
  ).data[:data]
end
