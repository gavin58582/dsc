# Configuration Data is available with $ConfigurationData
Configuration WebServer
{
    param($environment)
    Import-DscResource –ModuleName 'xPSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'xWebAdministration'
    Import-DscResource –ModuleName 'CengageCompositeResources'

    $splunkIndex = $ConfigurationData.NonNodeData.EnvironmentConfigurations[$environment].Splunk.Web
    $dynatraceHostGroup = $ConfigurationData.NonNodeData.EnvironmentConfigurations[$environment].Dynatrace.HostGroup
    $healthCheckConfigs = $ConfigurationData.NonNodeData.EnvironmentConfigurations[$environment].HealthCheckConfig
    $developerAccess = $environment -ne "Prod"

    $inputsConfTemplate = $ConfigurationData.NonNodeData.Splunk.InputsConf
    $InputsConf = $inputsConfTemplate -replace "#{Splunk:Index}", $splunkIndex
    $octopusEnvironments = @($environment)
    Node $configurationName {
        CengageWebHost NormalWebHostConfig {
            FileContents = $configurationName
        }
        Package UrlRewrite {
            #Install URL Rewrite module for IIS
            Ensure     = "Present"
            Name       = "IIS URL Rewrite Module 2"
            Path       = "http://download.microsoft.com/download/D/D/E/DDE57C26-C62C-4C59-A1BB-31D58B36ADA2/rewrite_amd64_en-US.msi"
            Arguments  = '/quiet'
            ProductId  = "38D32370-3A31-40E9-91D0-D236F47E3C4A"
            DependsOn  = "[CengageWebHost]NormalWebHostConfig"
            ReturnCode = @(0, 1603)
        }
        CengageOctopus octopus {
            OctopusEnvironments = $octopusEnvironments
            Space               = "NGLSync"
            Roles               = @("WebServer")
            Tenants             = "AWS"
            TenantTags          = "Hosting/AWS"
            DependsOn           = "[CengageWebHost]NormalWebHostConfig", "[Package]UrlRewrite"
        }
        if ($developerAccess) {
            CengageAdministrators extraAdmin {
                ConfigurationName   = $configurationName
                ExtraAdministrators = "awsweb\NGLSync Developers"
            }
        }
        else {
            CengageAdministrators DefaultAdmins {
                ConfigurationName = $configurationName
            }
        }

        CengageMonitoring cengageMonitoring {
            SentinelOneSite    = "cloud"
            SentinelOneGroup   = "default"
            DynatraceHostGroup = $dynatraceHostGroup
            SplunkInputsConf   = $InputsConf
            IsProduction       = $environment -eq "Prod"
        }

        ScheduledTaskHealthCheck healthCheck {
            HealthCheckConfiguration = $healthCheckConfigs
        }

    }
}