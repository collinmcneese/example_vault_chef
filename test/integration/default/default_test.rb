# InSpec test for recipe example_vault_chef::default

# The InSpec reference, with examples and extensive documentation, can be
# found at https://docs.chef.io/inspec/resources/

control 'example_vault_chef' do
  impact 0.7
  title 'Tests for Example Vault Chef cookbook'
  desc '
  This cookbook should consume secrets from a Vault server and store
  the results of the secret query in a file on the local filesystem.
  '

  ['/tmp/secretfile',
    '/tmp/my_application_config',
    '/tmp/secretfile_from_custom_resource',
    '/tmp/my_application_config_from_custom_resource'].each do |f|
    describe file(f) do
      it { should exist }
      its('content') { should match /key1_value/ }
      its('content') { should match /key2_value/ }
    end
  end
end
