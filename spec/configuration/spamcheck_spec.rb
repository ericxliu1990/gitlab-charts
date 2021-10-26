# frozen_string_literal: true
require 'spec_helper'
require 'hash_deep_merge'
require 'helm_template_helper'
require 'yaml'

describe 'spamcheck configuration' do
  let(:default_values) do
    YAML.safe_load(%(
      certmanager-issuer:
        email: test@example.com
    ))
  end

  let(:required_resources) do
    %w[Deployment ConfigMap Ingress Service HorizontalPodAutoscaler PodDisruptionBudget]
  end

  context 'with spamcheck disabled' do
    let(:spamcheck_disabled_values) do
      YAML.safe_load(%(
        global:
          spamcheck:
            enabled: false
      )).deep_merge(default_values)
    end

    let(:template) { HelmTemplate.new(spamcheck_disabled_values) }

    it 'does not create any spamcheck related resources' do
      required_resources.each do |resource|
        resource_name = "#{resource}/test-spamcheck"

        expect(template.resources_by_kind(resource)[resource_name]).to be_nil
      end
    end
  end

  context 'when spamcheck is enabled' do
    let(:spamcheck_enabled_values) do
      YAML.safe_load(%(
        global:
          spamcheck:
            enabled: true
      ))
    end

    let(:spamcheck_enabled_template) do
      HelmTemplate.new(default_values.merge(spamcheck_enabled_values))
    end

    it 'creates all spamcheck related required_resources' do
      required_resources.each do |resource|
        resource_name = "#{resource}/test-spamcheck"

        expect(spamcheck_enabled_template.resources_by_kind(resource)[resource_name]).to be_kind_of(Hash)
      end
    end

    describe 'when network policy is enabled' do
      let(:enable_network_policy) do
        YAML.safe_load(%(
          gitlab:
            spamcheck:
              networkpolicy:
                enabled: true
        )).deep_merge(spamcheck_enabled_values).deep_merge(default_values)
      end

      it 'creates a network policy object' do
        t = HelmTemplate.new(enable_network_policy)
        expect(t.exit_code).to eq(0), "Unexpected error code #{t.exit_code} -- #{t.stderr}"
        expect(t.dig('NetworkPolicy/test-spamcheck-v1', 'metadata', 'labels')).to include('app' => 'spamcheck')
      end
    end

    context 'When customer provides additional labels' do
      let(:spamcheck_label_values) do
        YAML.safe_load(%(
          global:
            common:
              labels:
                global: global
                foo: global
            spamcheck:
              enabled: true
            pod:
              labels:
                global_pod: true
            service:
              labels:
                global_service: true
          gitlab:
            spamcheck:
              common:
                labels:
                  global: spamcheck
                  spamcheck: spamcheck
              enabled: true
              podLabels:
                pod: true
                global: pod
              serviceAccount:
                create: true
                enabled: true
              serviceLabels:
                service: true
                global: service
        )).deep_merge(spamcheck_enabled_values.deep_merge(default_values))
      end

      it 'Populates the additional labels in the expected manner' do
        t = HelmTemplate.new(spamcheck_label_values)
        expect(t.exit_code).to eq(0), "Unexpected error code #{t.exit_code} -- #{t.stderr}"
        expect(t.dig('ConfigMap/test-spamcheck', 'metadata', 'labels')).to include('global' => 'spamcheck')
        expect(t.dig('Deployment/test-spamcheck', 'metadata', 'labels')).to include('foo' => 'global')
        expect(t.dig('Deployment/test-spamcheck', 'metadata', 'labels')).to include('global' => 'spamcheck')
        expect(t.dig('Deployment/test-spamcheck', 'metadata', 'labels')).not_to include('global' => 'global')
        expect(t.dig('Deployment/test-spamcheck', 'spec', 'template', 'metadata', 'labels')).to include('global' => 'pod')
        expect(t.dig('Deployment/test-spamcheck', 'spec', 'template', 'metadata', 'labels')).to include('pod' => 'true')
        expect(t.dig('Deployment/test-spamcheck', 'spec', 'template', 'metadata', 'labels')).to include('global_pod' => 'true')
        expect(t.dig('HorizontalPodAutoscaler/test-spamcheck', 'metadata', 'labels')).to include('global' => 'spamcheck')
        expect(t.dig('Ingress/test-spamcheck', 'metadata', 'labels')).to include('global' => 'spamcheck')
        expect(t.dig('PodDisruptionBudget/test-spamcheck', 'metadata', 'labels')).to include('global' => 'spamcheck')
        expect(t.dig('Service/test-spamcheck', 'metadata', 'labels')).to include('global' => 'service')
        expect(t.dig('Service/test-spamcheck', 'metadata', 'labels')).to include('global_service' => 'true')
        expect(t.dig('Service/test-spamcheck', 'metadata', 'labels')).to include('service' => 'true')
        expect(t.dig('Service/test-spamcheck', 'metadata', 'labels')).not_to include('global' => 'global')
        expect(t.dig('ServiceAccount/test-spamcheck', 'metadata', 'labels')).to include('global' => 'spamcheck')
      end
    end

    describe 'Secret key' do
      context 'when not explicitly provided by user' do
        it 'creates necessary secrets and mounts them on webservice deployment' do
          webservice_secret_mounts = spamcheck_enabled_template.projected_volume_sources(
            'Deployment/test-webservice-default',
            'init-webservice-secrets'
          )

          shared_secret_mount = webservice_secret_mounts.select do |item|
            item['secret']['name'] == 'test-gitlab-pages-secret' && item['secret']['items'][0]['key'] == 'shared_secret'
          end

          expect(shared_secret_mount.length).to eq(1)
        end

        it 'creates necessary secrets and mounts them on spamcheck deployment' do
          spamcheck_secret_mounts = spamcheck_enabled_template.projected_volume_sources(
            'Deployment/test-spamcheck',
            'init-spamcheck-secrets'
          )

          shared_secret_mount = spamcheck_secret_mounts.select do |item|
            item.dig('secret', 'name') == 'test-spamcheck-secret' && item.dig('secret', 'items', 0, 'key') == 'shared_secret'
          end

          expect(shared_secret_mount.length).to eq(1)
        end
      end

      context 'when secrets are provided by user' do
        let(:custom_secret_key) { 'spamcheck_custom_secret_key' }
        let(:custom_secret_name) { 'spamcheck_custom_secret_name' }

        let(:spamcheck_enabled_values) do
          YAML.safe_load(%(
            global:
              spamcheck:
                enabled: true
                appConfig:
                  gitlab_spamcheck:
                    secret: #{custom_secret_name}
                    key: #{custom_secret_key}
          ))
        end

        it 'mounts shared secret on webservice deployment' do
          webservice_secret_mounts = spamcheck_enabled_template.projected_volume_sources(
            'Deployment/test-webservice-default',
            'init-webservice-secrets'
          )

          shared_secret_mount = webservice_secret_mounts.select do |item|
            item['secret']['name'] == custom_secret_name && item['secret']['items'][0]['key'] == custom_secret_key
          end

          expect(shared_secret_mount.length).to eq(1)
        end

        it 'mounts shared secret on spamcheck deployment' do
          spamcheck_secret_mounts = spamcheck_enabled_template.projected_volume_sources(
            'Deployment/test-spamcheck',
            'init-spamcheck-secrets'
          )

          shared_secret_mount = spamcheck_secret_mounts.select do |item|
            item.dig('secret', 'name') == custom_secret_name && item.dig('secret', 'items', 0, 'key') == custom_secret_key
          end

          expect(shared_secret_mount.length).to eq(1)
        end
      end
    end
  end
end
