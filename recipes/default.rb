#
# Cookbook:: example_vault_chef
# Recipe:: default
#
# Copyright:: 2021, Collin McNeese, All Rights Reserved.

# Fetches the token/secretid to read from Vault via data bag
#  In a real environment this should be an encrypted data bag or some other secure
#  location for obtaining this data.
vault_token = data_bag_item('approle_tokens', 'default')["#{node['example_vault_chef']['vault_approle']}"]['token']

# Fetches the encrypted data_bag secret key from a data_bag and then uses that encryption key to read the
#  Vault secret token from the `encrypted_tokens` data_bag.
# key_content = data_bag_item('encrypted_data_bag_keys', 'default')['key'].strip()

# Optionally, store the key in the encrypted_databag_keys data_bag as base64 encoded to obfuscate a bit and then decode it:
# key_content = Base64.decode64(data_bag_item('encrypted_data_bag_keys', 'default')['base64_key']).strip()

vault_token = data_bag_item('encrypted_tokens', 'default', key_content)["#{node['example_vault_chef']['vault_approle']}"]['token']

# Use the get_hashi_vault_object helper from secrets_management to fetch secret data.
vault_data = get_hashi_vault_object(
  node['example_vault_chef']['vault_path'],
  node['example_vault_chef']['vault_server'],
  vault_token,
  node['example_vault_chef']['vault_approle']
).data[:data]

# Log the secret contents to show what the contents look like as a string
log vault_data.to_s do
  level :info
end

# Use the secret data obtained from Vault for populating our configuration file
file '/tmp/secretfile' do
  content <<~SECFILE
    key1 value: #{vault_data[:key1]}
    key2 value: #{vault_data[:key2]}
  SECFILE
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end
