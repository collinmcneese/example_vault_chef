#
# Cookbook:: example_vault_chef
# Recipe:: default
#

puts '------> Running in Test Kitchen mode' if ENV['TEST_KITCHEN']

# Call helper to populate the attribute node.run_state['vault_token']
#   Value of attribute node['example_vault_chef']['vault_token'] is used to determine secret location method
populate_run_state_vault_token()

include_recipe 'example_vault_chef::example' if node['example_vault_chef']['run_examples']
include_recipe 'example_vault_chef::example_custom_resource' if node['example_vault_chef']['run_examples']
