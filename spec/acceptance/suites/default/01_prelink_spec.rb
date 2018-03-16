require 'spec_helper_acceptance'
require 'json'

test_name 'simp::prelink'

describe 'simp::prelink class' do
  let(:manifest) {
    <<-EOS
      include 'simp::prelink'
    EOS
  }


  hosts.each do |host|
    context 'on #{host}' do
      context 'with default parameters' do
        it 'should apply manifest' do
          apply_manifest_on(host, manifest, :catch_failures => true)
        end

        it 'should be idempotent' do
          apply_manifest_on(host, manifest, :catch_changes => true)
        end

        it 'should ensure prelink package is absent' do
          expect( check_for_package(host, 'prelink') ).to be false
        end
      end

      context 'with prelink enabled' do
        let(:prelink_enabled_hiera) {
          <<-EOS
simp::prelink::enable: true
         EOS
         }

        it 'should apply manifest' do
          set_hieradata_on(host, prelink_enabled_hiera)
          apply_manifest_on(host, manifest, :catch_failures => true)
        end

        it 'should be idempotent' do
          apply_manifest_on(host, manifest, :catch_changes => true)
        end

        it 'should install prelink package' do
          expect( check_for_package(host, 'prelink') ).to be true
        end

        it 'should enable prelink' do
          facts = JSON.load(on(host, 'puppet facts').stdout)
          expect( facts['values']['prelink'] ).to_not be nil
          expect( facts['values']['prelink']['enabled'] ).to be true
        end

        it 'should run prelink' do
          # first see if prelink cron job has already run 
          result = on(host, 'ls /etc/prelink.cache', :acceptable_exit_codes => [0,2])

          if result.exit_code == 2
            # prelink cron job has not yet been run, so try to run it
            on(host, '/etc/cron.daily/prelink')
            on(host, 'ls /etc/prelink.cache')
          end
        end
      end

      context 'with prelink disabled after being enabled' do
        let(:prelink_disabled_hiera) {
          <<-EOS
simp::prelink::enable: false
         EOS
         }

        it 'should apply manifest' do
          set_hieradata_on(host, prelink_disabled_hiera)
          apply_manifest_on(host, manifest, :catch_failures => true)
        end

        it 'should be idempotent' do
          apply_manifest_on(host, manifest, :catch_changes => true)
        end

        it 'should remove prelink cache when prelink is disabled' do
          on(host, 'ls /etc/prelink.cache', :acceptable_exit_codes => [2])
        end

        it 'should uninstall prelink package' do
          expect( check_for_package(host, 'prelink') ).to be false
        end
      end
    end
  end
end