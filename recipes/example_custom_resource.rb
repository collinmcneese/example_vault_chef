#
# Cookbook:: example_vault_chef
# Recipe:: example_custom_resource
#

# uses the custom resource secret_hashicorp_vault to fetch data from vault target and saves as
#  node.run_state['my_app_secret']
secret_hashicorp_vault 'my_app_secret' do
  vault_address         node['example_vault_chef']['vault_server']
  vault_namespace       nil
  vault_path            node['example_vault_chef']['vault_path']
  vault_role            node['example_vault_chef']['vault_approle']
  vault_token           node.run_state['vault_token']
  ssl_verify            true
  action                :fetch
end

# Log the secret contents to show what the contents look like as a string
log node.run_state['my_app_secret'].to_s do
  level :info
end

# Use the secret data obtained from Vault for populating our configuration file
file '/tmp/secretfile_from_custom_resource' do
  content lazy {
    <<~SECFILE
    key1 value: #{node.run_state['my_app_secret'][:key1]}
    key2 value: #{node.run_state['my_app_secret'][:key2]}
    SECFILE
  }
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

template '/tmp/my_application_config_from_custom_resource' do
  source 'example.yml.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables lazy {
    {
      user: node.run_state['my_app_secret'][:key1],
      password: node.run_state['my_app_secret'][:key2],
    }
  }
  action :create
end
