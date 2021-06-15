#
# Cookbook:: example_vault_chef
# Recipe:: default
#

puts '------> Running in Test Kitchen mode' if ENV['TEST_KITCHEN']

include_recipe 'example_vault_chef::example' if node['example_vault_chef']['run_examples']
include_recipe 'example_vault_chef::example_custom_resource' if node['example_vault_chef']['run_examples']
