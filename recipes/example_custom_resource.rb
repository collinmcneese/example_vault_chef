#
# Cookbook:: example_vault_chef
# Recipe:: example_custom_resource
#

# uses the custom resource secret_hashicorp_vault to fetch data from vault target and saves as
#  node.run_state['my_app_secret']
# This example pulls data from node attributes for easy exensibility, this is the example syntax for this resource:
# secret_hashicorp_vault 'my_app_secret' do
#   vault_address               'https://Vault-FQDN:8200'
#   vault_namespace             'my/namespace'
#   vault_path                  'secret/data/name'
#   vault_role                  'my-app-role'
#   vault_token_method          'token-file'
#   vault_token_method_options({ 'vault_token_file' => '/path/to/token/file' })
#   attribute_target            'my_app_secret'
#   ssl_verify                  true
#   action                      :fetch
# end
secret_hashicorp_vault 'my_app_secret' do
  vault_address               node['example_vault_chef']['vault_server']
  vault_namespace             nil
  vault_path                  node['example_vault_chef']['vault_path']
  vault_role                  node['example_vault_chef']['vault_approle']
  vault_token_method          node['example_vault_chef']['vault_token_method']
  vault_token_method_options  node['example_vault_chef']['vault_token_method_options']
  ssl_verify                  true
  action                      :fetch
end

# Log the secret contents to show what the contents look like as a string
log 'vault_data' do
  message lazy { node.run_state['my_app_secret'].to_s }
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
