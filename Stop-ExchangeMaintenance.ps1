<#    
    DESCRIPTION
        Stops exchange 2016 server from being in maintenance and function in the DAG/mail flow again.
#>

function Stop-ExchangeMaintenance
{
    param
    (
        [parameter(Mandatory = $true)]
        [validateNotNullOrEmpty()]
        [String]$maintServe
    )
    
    BEGIN 
    {
    }
    PROCESS
    {
        Write-Verbose "Taking Server out of Maintenance"
        Set-ServerComponentState $maintServer -Component ServerWideOffline -State Active -Requester Maintenance
        
        Write-Verbose "Restart DAG activity"
        Resume-ClusterNode $maintServer
        
        Write-Verbose "Allow Database Activation"
        Set-MailboxServer $maintServer -DatabaseCopyActivationDisabledAndMoveNow $False
        
        Write-Verbose "Set database back to the original setting"
        Set-MailboxServer $maintServer -DatabaseCopyAutoActivationPolicy Unrestricted
        
        Write-Verbose "Reactivate hub transport"
        Set-ServerComponentstate $maintServer -Component HubTransport -State Active -Requester Maintenance
        
        Write-Verbose "Restart Transport Services"
        Restart-service msexchangetransport
        Restart-service msexchangefrontendtransport
    }
    END
    {
    }
}
