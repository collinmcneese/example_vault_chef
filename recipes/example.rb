#
# Cookbook:: example_vault_chef
# Recipe:: example
#

def get_hashi_vault_object(vault_path, vault_address, vault_token, vault_role = nil, vault_namespace = nil)
  require 'vault'

  # Need to set the vault address
  Vault.address = vault_address
  # Authenticate with the token
  Vault.token = vault_token

  # Add namespace if passed (default is nil)
  Vault.namespace = vault_namespace

  Vault.ssl_verify = false

  if vault_role # Authenticate to Vault using the role_id
    begin
      approle_id = Vault.approle.role_id(vault_role)
      secret_id = Vault.approle.create_secret_id(vault_role).data[:secret_id]
      Vault.auth.approle(approle_id, secret_id)
    rescue => err
      log 'Unable to fetch data from vault, exception returned when trying to authenticate with approle'
      log "#{err}"
    end
  end

  # Attempt to read the secret
  begin
    secret = Vault.logical.read(vault_path)
  rescue => err
    log 'Unable to fetch data from vault, exception returned when trying to obtain data'
    log "#{err}"
  end

  # return the secret object
  secret
end

# Set the vault token using the defined methods
node.run_state['vault_token_example_recipe'] = case node['example_vault_chef']['vault_token_method']
                                               when 'data-bag'
                                                 # Fetches the token/secretid to read from Vault via data bag
                                                 #  In a real environment this should be an encrypted data bag or some other secure
                                                 #  location for obtaining this data.
                                                 data_bag_item('approle_tokens', 'default')["#{node['example_vault_chef']['vault_approle']}"]['token']
                                               when 'token-file'
                                                 # Fetches the token/secretid from a file on the filesystem of the server
                                                 # Mock up creating the token_file for test-kitchen only
                                                 file node['example_vault_chef']['vault_token_file'] do
                                                   content node['example_vault_chef']['vault_token_file_content'].to_s
                                                   owner 'root'
                                                   group 'root'
                                                   mode '0600'
                                                   only_if { ENV['TEST_KITCHEN'] == '1' }
                                                 end.run_action(:create)

                                                 # Reads the first line of a file
                                                 File.read(node['example_vault_chef']['vault_token_file']).split()[0] if File.exist?(node['example_vault_chef']['vault_token_file'])
                                               when 'encrypted-data-bag-from-bag'
                                                 # Fetches the encrypted data_bag secret key from a data_bag and then uses that encryption key to read the
                                                 #  Vault secret token from the `encrypted_tokens` data_bag.
                                                 key_content = data_bag_item('encrypted_data_bag_keys', 'default')['key'].strip()
                                                 data_bag_item('encrypted_tokens', 'default', key_content)["#{node['example_vault_chef']['vault_approle']}"]['token']
                                               when 'encrypted-data-bag-from-file'
                                                 # Fetches the encrypted data_bag secret key from a local file and then uses that encryption key to read the
                                                 #  Vault secret token from the `encrypted_tokens` data_bag.
                                                 cookbook_file '/tmp/keyfile' do
                                                   source 'mysecretfile'
                                                   owner 'root'
                                                   group 'root'
                                                   mode '0400'
                                                   action :create
                                                   compile_time true
                                                 end

                                                 key_content = Chef::EncryptedDataBagItem.load_secret('/tmp/keyfile')
                                                 data_bag_item('encrypted_tokens', 'default', key_content)["#{node['example_vault_chef']['vault_approle']}"]['token']
                                               when 'secret-from-api'
                                                 # Fetches the token/secretid to read from Vault via external API
                                                 api_data = api_json_fetch(node['example_vault_chef']['api_secret_server'].to_s)
                                                 api_data['chef-role']['token']
                                               end

# Use the get_hashi_vault_object helper from secrets_management to fetch secret data.
vault_response_object = get_hashi_vault_object(
  node['example_vault_chef']['vault_path'],
  node['example_vault_chef']['vault_server'],
  node.run_state['vault_token_example_recipe'],
  node['example_vault_chef']['vault_approle'],
  node['example_vault_chef']['vault_namespace']
)

node.run_state['vault_data_example_recipe'] = vault_response_object.data[:data] if vault_response_object.respond_to?(:data)

# Log the secret contents to show what the contents look like as a string
log node.run_state['vault_data_example_recipe'].to_s do
  level :info
end

# Use the secret data obtained from Vault for populating our configuration file
file '/tmp/secretfile' do
  content <<~SECFILE
    key1 value: #{node.run_state['vault_data_example_recipe'][:key1] if node.run_state['vault_data_example_recipe']}
    key2 value: #{node.run_state['vault_data_example_recipe'][:key2] if node.run_state['vault_data_example_recipe']}
  SECFILE
  owner 'root'
  group 'root'
  mode '0755'
  action :create
  not_if { node.run_state['vault_data_example_recipe'].nil? }
end

template '/tmp/my_application_config' do
  source 'example.yml.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables lazy {
    {
      user: node.run_state['vault_data_example_recipe'][:key1],
      password: node.run_state['vault_data_example_recipe'][:key2],
    }
  }
  action :create
  not_if { node.run_state['vault_data_example_recipe'].nil? }
end
