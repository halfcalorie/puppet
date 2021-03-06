test_name 'oregano module search should print a reasonable message on communication errors'

tag 'audit:low',
    'audit:integration'

step 'Setup'
stub_hosts_on(master, 'forgeapi.oregano.com' => '127.0.0.2')

step "Search against a non-existent Forge"
on master, oregano("module search yup"), :acceptable_exit_codes => [1] do

  assert_match <<-STDOUT, stdout
\e[mNotice: Searching https://forgeapi.oregano.com ...\e[0m
STDOUT

assert_no_match /yup/,
  stdout,
  'Found a reference to a fake module when errors should have prevented us from getting here'
end
