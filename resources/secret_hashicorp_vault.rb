# vault_secret_fetch

resource_name :secret_hashicorp_vault
provides :secret_hashicorp_vault

unified_mode true

description 'Use the **secret_hashicorp_vault** resource to fetch data from a HashiCorp Vault provider using a token.'
examples <<~DOC
  ```ruby
  secret_hashicorp_vault 'my_app_secret' do
    vault_address         'https://Vault-FQDN:8200'
    vault_namespace       'my/namespace'
    vault_path            'secret/data/name'
    vault_role            'my-app-role'
    vault_token           'vault_access_token'
    attribute_target      'my_app_secret'
    ssl_verify            true
    action                :fetch
  end
  ```
DOC

property :vault_address, String, required: true,
  description: 'Address of the target vault server, example https://Vault-FQDN.localdomain:8200'
property :vault_namespace, String,
  description: 'Vault namespace to use, if required.'
property :vault_path, String,
  description: 'Path to the secret data which should be fetched from the Vault server'
property :vault_role, String,
  description: 'Vault app-role name to use, if required.'
property :vault_token, String, required: true,
  description: 'Vault token to use for authentication.'
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
  vault_address = new_resource.vault_address
  vault_namespace = new_resource.vault_namespace
  vault_path = new_resource.vault_path
  vault_role = new_resource.vault_role
  vault_token = new_resource.vault_token
  attribute_target = new_resource.attribute_target
  ssl_verify = new_resource.ssl_verify

  log "Fetching Vault data from #{new_resource.vault_address}"

  node.run_state[attribute_target] = get_hashi_vault_object(
    vault_path,
    vault_address,
    vault_token,
    vault_role,
    vault_namespace,
    ssl_verify
  ).data[:data]
end
