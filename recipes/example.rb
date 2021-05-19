#
# Cookbook:: example_vault_chef
# Recipe:: example
#

# Use the get_hashi_vault_object helper from secrets_management to fetch secret data.
node.run_state['vault_data'] = get_hashi_vault_object(
  node['example_vault_chef']['vault_path'],
  node['example_vault_chef']['vault_server'],
  node.run_state['vault_token'],
  node['example_vault_chef']['vault_approle'],
  node['example_vault_chef']['vault_namespace']
).data[:data]

# Log the secret contents to show what the contents look like as a string
log node.run_state['vault_data'].to_s do
  level :info
end

# Use the secret data obtained from Vault for populating our configuration file
file '/tmp/secretfile' do
  content <<~SECFILE
    key1 value: #{node.run_state['vault_data'][:key1]}
    key2 value: #{node.run_state['vault_data'][:key2]}
  SECFILE
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

template '/tmp/my_application_config' do
  source 'example.yml.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables lazy {
    {
      user: node.run_state['vault_data'][:key1],
      password: node.run_state['vault_data'][:key2],
    }
  }
  action :create
end
