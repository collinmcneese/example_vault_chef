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
  description: ''
property :vault_namespace, String,
  description: ''
property :vault_path, String,
  description: ''
property :vault_role, String,
  description: ''
property :vault_token, String, required: true,
  description: ''
property :attribute_target, [String, Array], name_property: true,
  description: ''
property :ssl_verify, [true, false], default: true,
  description: ''

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

  node.run_state[attribute_target] = get_hashi_vault_object(
    vault_path,
    vault_address,
    vault_token,
    vault_role,
    vault_namespace,
    ssl_verify
  ).data[:data]
end
