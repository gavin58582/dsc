# Configuration Data is available with $ConfigurationData
Configuration Sql
{
    param($environment)
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'CengageCompositeResources'
    Import-DscResource -ModuleName 'NetworkingDsc' -ModuleVersion 8.1.0
    $splunkIndex = $ConfigurationData.NonNodeData.EnvironmentConfigurations[$environment].Splunk.Web
    $dynatraceHostGroup = $ConfigurationData.NonNodeData.EnvironmentConfigurations[$environment].Dynatrace.HostGroup
    $maxMemory = $ConfigurationData.NonNodeData.EnvironmentConfigurations[$environment].SqlServer.MaxMemory
    $InputsConf = "[WinEventLog://Application]
    index = #{Splunk:Index}
    [WinEventLog://Security]
    index = #{Splunk:Index}
    [WinEventLog://System]
    index = #{Splunk:Index}" -replace "#{Splunk:Index}", $splunkIndex
    
    [PSCredential] $DomCredential = Get-VaultPsCredential "vault/topfolder/subfolder/...."

    Node $configurationName {
        CengageAdministrators admins {
            ExtraAdministrators = $DomCredential.UserName
            ConfigurationName   = $configurationName
        }
        CengageSqlHost SqlHostConfig {
            ConfigurationName = $ConfigurationName
            DomCredential     = $DomCredential
            DependsOn         = "securitygroup"
            TCPPort           = 1433
        }
        CengageMonitoring cengageMonitoring {
            SentinelOneSite    = "cloud"
            SentinelOneGroup   = "default"
            DynatraceHostGroup = $dynatraceHostGroup
            SplunkInputsConf   = $InputsConf
            IsProduction       = $environment -eq "Prod"
        }
        Firewall EnableV4PingIn {
            Name    = "vm-monitoring-icmpv4"
            Enabled = "True"
        }
    }
}
