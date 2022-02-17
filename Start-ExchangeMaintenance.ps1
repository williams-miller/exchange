<# 
DESCRIPTION
Places an exchange 2016 server in maintenance in prep for patching.
#>

function Start-ExchangeMaintenance
{
    param
   (
    [parameter(Mandatory = $true)]
    [validateNotNullOrEmpty()]
    [String]$maintServer,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$failoverServerFQDN
    )

    BEGIN
    {

    }

    PROCESS
    {
        Write-Verbose "Draining Mail Queues"
        Set-ServerComponentState $maintServer -Component HubTransport -State Draining -Requester Maintenance

        Write-Verbose "Restarting Transport Services"
        Restart-Service MSExchangeTransport
        Restart-Service MSExchangeFrontEndTransport

        Write-Verbose "Redicting pending mail to Failover Server"
        Redirect-Message -Server $maintServer -Target $failoverServerFQDN

        Write-Verbose "Suspending DAG activity"
        Suspend-ClusterNode $maintServer

       Write-Verbose "Moving any Active Database Ownership to other servers"
       Set-MailboxServer $maintServer -DatabaseCopyActivationDisabledAndMoveNow $True

       Write-Verbose "Blocking mmaintenance server from hosting active database copies"
       Set-MailboxServer $maintServer -DatabaseCopyAutoActivationPolicy Blocked

       Write-Verbose "Placing Server in maintenance"
       Set-ServerComponentState $maintServer -Component ServerWideOffline -State Inactive -Requester Maintenance
    }

    END
    {

    } 
}
