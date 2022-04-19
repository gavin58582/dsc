# Configuration Data is available with $ConfigurationData
Configuration Ftp
{
    param($environment)
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'xWebAdministration'
    Import-DscResource -ModuleName 'CengageCompositeResources'

    $splunkIndex = $ConfigurationData.NonNodeData.EnvironmentConfigurations[$environment].Splunk.Web
    $dynatraceHostGroup = $ConfigurationData.NonNodeData.EnvironmentConfigurations[$environment].Dynatrace.HostGroup # HasLocalAccountForFtp

    $odbcDsnCollection = $ConfigurationData.NonNodeData.EnvironmentConfigurations[$environment].OdbcDsn
    $inputsConfTemplate = $ConfigurationData.NonNodeData.Splunk.InputsConf
    $InputsConf = $inputsConfTemplate -replace "#{Splunk:Index}", $splunkIndex
    $octopusEnvironments = if ($environment -eq "Prod") {@("Prod")} else {@("Shared Non-Prod")}

    Node $configurationName {
        CengageMonitoring cengageMonitoring {
            SentinelOneSite    = "cloud"
            SentinelOneGroup   = "default"
            DynatraceHostGroup = $dynatraceHostGroup
            SplunkInputsConf   = $InputsConf
            IsProduction       = $environment -eq "Prod"
        }
        CengageAdministrators extraAdmin {
            ConfigurationName   = $configurationName
            # Remote access to devs for production because the application requires RDP access to be maintained.
            # ServU has no automation capabilities.
            ExtraAdministrators = "awsweb\NGLSync Developers"
        }
        CengageOctopus octopus {
            OctopusEnvironments = $octopusEnvironments
            Space               = "NGLSync"
            Roles               = @("Ftp")
            Tenants             = "AWS"
            TenantTags          = "AWS"
        }
        foreach ($odbc in $odbcDsnCollection) {
            OdbcConnection $odbc.ODBCName {
                SQLServerName = $odbc.SQLServerName
                DatabaseName  = $odbc.DatabaseName
                ODBCName      = $odbc.ODBCName
            }
        }
    }
}