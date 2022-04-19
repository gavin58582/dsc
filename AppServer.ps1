# Configuration Data is available with $ConfigurationData
Configuration AppServer
{
    param($environment)
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'xWebAdministration'
    Import-DscResource –ModuleName 'CengageCompositeResources'

    $splunkIndex = $ConfigurationData.NonNodeData.EnvironmentConfigurations[$environment].Splunk.Web
    $dynatraceHostGroup = $ConfigurationData.NonNodeData.EnvironmentConfigurations[$environment].Dynatrace.HostGroup
    $developerAccess = $environment -ne "Prod"

    $inputsConfTemplate = $ConfigurationData.NonNodeData.Splunk.InputsConf
    $InputsConf = $inputsConfTemplate -replace "#{Splunk:Index}", $splunkIndex
    $octopusEnvironments = @($environment)
    Node $configurationName {
        CengageOctopus octopus {
            OctopusEnvironments = $octopusEnvironments
            Space               = "NAME"
            Roles               = @("AppServer")
            Tenants             = "TenantName"
            TenantTags          = "EnvironmentTag"
        }
        CengageWebHost NormalWebHostConfig {
            FileContents = $configurationName
        }
        Dynatrace dt {
            HostGroup = $dynatraceHostGroup
        }
        Splunk splunk {
            InputsConf   = $InputsConf
            IsProduction = $environment -eq "Prod"
        }
        if ($developerAccess) {
            CengageAdministrators extraAdmin {
                ExtraAdministrators = "domain\securitygroup"
                ConfigurationName   = $configurationName
            }
        }
        else {
            CengageAdministrators DefaultAdmins {
                ConfigurationName = $configurationName
            }
        }

    }
}
