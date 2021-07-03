default['example_vault_chef']['vault_server']               = 'http://host.docker.internal:8200'
default['example_vault_chef']['vault_path']                 = 'secret/data/demo'
default['example_vault_chef']['vault_approle']              = 'chef-role'
default['example_vault_chef']['vault_token_method']         = 'data-bag'
default['example_vault_chef']['vault_token_method_options'] = {
  'data_bag'      => 'approle_tokens',
  'data_bag_item' => 'default',
}
default['example_vault_chef']['api_secret_server']          = 'http://host.docker.internal:10811'
default['example_vault_chef']['vault_namespace']            = nil

# used with 'token-file' option of 'vault_token' attribute
default['example_vault_chef']['vault_token_file']           = '/etc/chef/vault_token_file'

# This is populated in this example for usage with test kitchen.
#  Sensitive data should not be stored as a regular node attibute in a real environment.
default['example_vault_chef']['vault_token_file_content']   = 's.CO4JmM6AzAYlgJywEct35kjg'
