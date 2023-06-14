Clear-Host

function AddTitleBlock {
    Param ([string]$Title, $TitleHeight)

    IF ([string]::IsNullOrWhiteSpace($global:Json)) { $global:Json = $JsonHeader }

    IF (!([string]::IsNullOrWhiteSpace($TitleHeight))) { $headerheight = $TitleHeight } Else { $headerheight = 2 }

    $global:width = 0
    $global:height=$global:height+$global:MaxWidgetHeight

    $widget_header = $nl`
    +$__2tab__+'{'+$nl`
    +$____3tab____+'"height": '+$headerheight+','+$nl`
    +$____3tab____+'"width": 24,'+$nl`
    +$____3tab____+'"y": '+$global:height+','+$nl`
    +$____3tab____+'"x": '+$global:width+','+$nl`
    +$____3tab____+'"type": "text",'+$nl`
    +$____3tab____+'"properties": {'+$nl`
    +$______4tab______+'"markdown": "'+$Title+'",'+$nl`
    +$______4tab______+'"background": "transparent"'+$nl`
    +$____3tab____+'}'+$nl`
    +$__2tab__+'},'
    
    $global:Json = $global:Json + $widget_header

    $global:height=$global:height+$headerheight
    $global:MaxWidgetHeight = $headerheight
}

function AddWidget {
    Param ($WidgetData, $WidgetType, $incX, $incY, $voldata, $leftPoint, $InstanceEbsInfo)

    #Set Defaults
    $WidgetHeight = 4 
    $WidgetWidth = 4
    $type = 'metric'
    $view = 'timeSeries'
    $stat = 'Maximum'
    $period = 300
    $stacked = 'true'
    $metric_region = $global:RegionFilter
    $totalAllocatedIOPS = 0
    $totalAllocatedThroughput = 0

    ForEach ($data in $WidgetData) {
        switch ($data.Split(':')[0]) {
            "height" { $WidgetHeight = $data.Split(':')[1].trim() } 
            "Width" { $WidgetWidth = $data.Split(':')[1].trim() } 
            "type" { $type = $data.Split(':')[1].trim() } 
            "view" { $view = $data.Split(':')[1].trim() } 
            "stat" { $stat = $data.Split(':')[1].trim() } 
            "period" { $period = $data.Split(':')[1].trim() } 
            "stacked" { $stacked = $data.Split(':')[1].trim() } 
            "region" { $metric_region = $data.Split(':')[1].trim() } 
            "title" { $metric_title = $data.Split(':')[1].trim() } 
            "instanceid" { $instance_id = $data.Split(':')[1].trim() } 
            "DBInstanceIdentifier" { $DBInstanceIdentifier = $data.Split(':')[1].trim() } 
            "recordtype" { $recordtype = $data.Split(':')[1].trim() } 
        }
    }

    if ($WidgetHeight -gt $global:MaxWidgetHeight) { $global:MaxWidgetHeight = $WidgetHeight }

    IF ($WidgetType -eq 'CPU') {

        $expression=''`
        +$______4tab______+'"metrics": ['+$nl

        if ($recordtype -eq 'EC2') {
            $expression = $expression+`    
            $________5tab________+'[ "AWS/EC2", "CPUUtilization", "InstanceId", "'+$instance_id+'" ]'+$nl
        }
        if ($recordtype -eq 'RDS') {
            $expression = $expression+`    
            $________5tab________+'[ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "'+$DBInstanceIdentifier+'" ]'+$nl
        }

        $expression=$expression+` 
        $______4tab______+'],'

        $labelString = $__________6tab__________+'"label": "Percent",'+$nl
    }
    Elseif ($WidgetType -eq 'EBS-IOPS') {

        $volumes = $voldata 

        $expressionSub=''
        $volCount = 0

        $expression=''`
        +$______4tab______+'"metrics": ['+$nl

        if ($recordtype -eq 'EC2') {

            ForEach ($volume in $volumes) {
                $volCount++
                if ($volCount -eq $volumes.count) {
                    $expressionSub = $expressionSub+$________5tab________+'[ "AWS/EBS", "VolumeReadOps", "VolumeId", "'+$volume.VolumeId+'", { "label": "'+$volume.VolumeId+'", "id": "mr'+$volCount+'", "visible": false } ],'+$nl
                    $expressionSub = $expressionSub+$________5tab________+'[ "AWS/EBS", "VolumeWriteOps", "VolumeId", "'+$volume.VolumeId+'", { "label": "'+$volume.VolumeId+'", "id": "mw'+$volCount+'", "visible": false } ]'+$nl
                }
                else
                {
                    $expressionSub = $expressionSub+$________5tab________+'[ "AWS/EBS", "VolumeReadOps", "VolumeId", "'+$volume.VolumeId+'", { "label": "'+$volume.VolumeId+'", "id": "mr'+$volCount+'", "visible": false } ],'+$nl
                    $expressionSub = $expressionSub+$________5tab________+'[ "AWS/EBS", "VolumeWriteOps", "VolumeId", "'+$volume.VolumeId+'", { "label": "'+$volume.VolumeId+'", "id": "mw'+$volCount+'", "visible": false } ],'+$nl
                }

            }

            $SumString = "SUM(["

            for ($i=1; $i -le $volCount; $i++) {
                if ($i -eq 1) {
                    $SumString=$SumString+"((mr$i+mw$i) / (PERIOD(mr$i)))" 
                }
                else {
                    $SumString=$SumString+" + ((mr$i+mw$i) / (PERIOD(mr$i)))" 
                }
            }
            $SumString=$SumString+"])" 

            $expression=$expression`
            +$________5tab________+'[ { "expression": "'+$SumString+'", "label": "Total IOPS" } ],'+$nl  

            $expression=$expression+$expressionSub

            $expression=$expression`
            +$______4tab______+'],'

        }

    #    if ($recordtype -eq 'RDS') {
    #
    #        $expression = $expression`
    #        +$________5tab________+'[ { "expression": "SUM(METRICS()) ", "label": "Total IOPS" } ],'+$nl`
    #        +$________5tab________+'[ "AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", "'+$DBInstanceIdentifier+'", { "label": "ReadIOPS", "id": "mr1", "visible": false } ],'+$nl`
    #        +$________5tab________+'[ "AWS/RDS", "WriteIOPS", "DBInstanceIdentifier", "'+$DBInstanceIdentifier+'", { "label":"WriteIOPS", "id": "mw1", "visible": false } ]'+$nl`
    #        +$______4tab______+'],'
    #    }

        $labelString = $__________6tab__________+'"label": "IOPS",'+$nl

    }
    Elseif  ($WidgetType -eq 'EBS-IOPS-Detail') {

        $volume = $voldata 

        $expression=''`
        +$______4tab______+'"metrics": ['+$nl`
        +$________5tab________+'[ { "expression": "SUM([m1,m2]) / (PERIOD(m1))", "label": "'+$volume.VolumeId+'" } ],'+$nl`
        +$________5tab________+'[ "AWS/EBS", "VolumeReadOps", "VolumeId", "'+$volume.VolumeId+'", { "label": "'+$volume.VolumeId+'", "id": "m1", "visible": false } ],'+$nl`
        +$________5tab________+'[ "AWS/EBS", "VolumeWriteOps", "VolumeId", "'+$volume.VolumeId+'", { "label": "'+$volume.VolumeId+'", "id": "m2", "visible": false } ]'+$nl`
        +$______4tab______+'],'

        $labelString = $__________6tab__________+'"label": "IOPS",'+$nl
    }
    Elseif ($WidgetType -eq 'EBS-Throughput') {

        $volumes = $voldata 

        $expressionSub=''
        $volCount = 0

        $expression=''`
        +$______4tab______+'"metrics": ['+$nl

        if ($recordtype -eq 'EC2') {

            ForEach ($volume in $volumes) {
                $volCount++
                if ($volCount -eq $volumes.count) {
                    $expressionSub = $expressionSub+$________5tab________+'[ "AWS/EBS", "VolumeReadBytes", "VolumeId", "'+$volume.VolumeId+'", { "label": "'+$volume.VolumeId+'", "id": "mr'+$volCount+'", "visible": false } ],'+$nl
                    $expressionSub = $expressionSub+$________5tab________+'[ "AWS/EBS", "VolumeWriteBytes", "VolumeId", "'+$volume.VolumeId+'", { "label": "'+$volume.VolumeId+'", "id": "mw'+$volCount+'", "visible": false } ]'+$nl
                }
                else
                {
                    $expressionSub = $expressionSub+$________5tab________+'[ "AWS/EBS", "VolumeReadBytes", "VolumeId", "'+$volume.VolumeId+'", { "label": "'+$volume.VolumeId+'", "id": "mr'+$volCount+'", "visible": false } ],'+$nl
                    $expressionSub = $expressionSub+$________5tab________+'[ "AWS/EBS", "VolumeWriteBytes", "VolumeId", "'+$volume.VolumeId+'", { "label": "'+$volume.VolumeId+'", "id": "mw'+$volCount+'", "visible": false } ],'+$nl
                }
            
            }

            $expressionSub = $expressionSub+$______4tab______+'],'

            $SumString = "(SUM(["

            for ($i=1; $i -le $volCount; $i++) {
                if ($i -eq 1) {
                    $SumString=$SumString+"((mr$i+mw$i) / (PERIOD(mr$i)))" 
                }
                else {
                    $SumString=$SumString+" + ((mr$i+mw$i) / (PERIOD(mr$i)))" 
                }
            }
            $SumString=$SumString+"])) / 1000000" 

            $expression=$expression`
            +$________5tab________+'[ { "expression": "'+$SumString+'", "label": "Total MiB/s" } ],'+$nl  

            $expression=$expression+$expressionSub

        }

       # if ($recordtype -eq 'RDS') {
       #
       #     $expression=$expression`
       #     +$________5tab________+'[ { "expression": "SUM(METRICS()) / 125000", "label": "Total MB/s", "id": "e1" } ],'+$nl`
       #     +$________5tab________+'[ "AWS/RDS", "ReadThroughput", "DBInstanceIdentifier", "'+$DBInstanceIdentifier+'", { "label": "rdsvolume", "id": "mr1", "visible": false } ],'+$nl`
       #     +$________5tab________+'[ "AWS/RDS", "WriteThroughput", "DBInstanceIdentifier", "'+$DBInstanceIdentifier+'", { "label": "rdsvolume", "id": "mw1", "visible": false } ]'+$nl`
       #     +$______4tab______+'],'
       # }

        $labelString = $__________6tab__________+'"label": "MB/s",'+$nl

    }
    Elseif  ($WidgetType -eq 'EBS-Throughput-Detail') {

        $volume = $voldata 

        $expression=''`
        +$______4tab______+'"metrics": ['+$nl`
        +$________5tab________+'[ { "expression": "(SUM([m1,m2]) / (PERIOD(m1))) / 1024 / 1024", "label": "'+$volume.VolumeId+'" } ],'+$nl`
        +$________5tab________+'[ "AWS/EBS", "VolumeReadBytes", "VolumeId", "'+$volume.VolumeId+'", { "label": "'+$volume.VolumeId+'", "id": "m1", "visible": false } ],'+$nl`
        +$________5tab________+'[ "AWS/EBS", "VolumeWriteBytes", "VolumeId", "'+$volume.VolumeId+'", { "label": "'+$volume.VolumeId+'", "id": "m2", "visible": false } ]'+$nl`
        +$______4tab______+'],'

        $labelString = $__________6tab__________+'"label": "MiB/s",'+$nl
    }
    Elseif ($WidgetType -eq 'RDS-Storage') {

        $volumes = $voldata  -split '~@~'

        $Inst_Title = $volumes[0]
        $Inst_StorageType = $volumes[1]
        $inst_AllocatedStorage = $volumes[2]
        $inst_rdsIops = $volumes[3]
        $inst_rdsiopsburst = $volumes[4]
        $inst_rdsThroughput = $volumes[5]
        $inst_rdsThroughputburst = $volumes[6]

        $metric_BaselineIops = $inst_rdsIops
        $metric_MaximumIops = $inst_rdsiopsburst  

        $metric_BaselineThroughputInMBps = $inst_rdsThroughput
        $metric_MaximumThroughputInMBps = $inst_rdsThroughputburst

        $expression=''`
        +$______4tab______+'"metrics": ['+$nl`
        +$________5tab________+'[ { "expression": "SUM(METRICS()) ", "label": "Total IOPS" } ],'+$nl`
        +$________5tab________+'[ "AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", "'+$DBInstanceIdentifier+'", { "label": "ReadIOPS", "id": "mr1", "visible": false } ],'+$nl`
        +$________5tab________+'[ "AWS/RDS", "WriteIOPS", "DBInstanceIdentifier", "'+$DBInstanceIdentifier+'", { "label":"WriteIOPS", "id": "mw1", "visible": false } ]'+$nl`
        +$______4tab______+'],'

        $labelString = $__________6tab__________+'"label": "IOPS",'+$nl

        $widget = $nl`
        +$__2tab__+'{'+$nl`
        +$____3tab____+'"height": '+$WidgetHeight+','+$nl`
        +$____3tab____+'"width": '+$WidgetWidth+','+$nl`
        +$____3tab____+'"y": '+$global:height+','+$nl`
        +$____3tab____+'"x": '+$global:width+','+$nl`
        +$____3tab____+'"type": "'+$type+'",'+$nl`
        +$____3tab____+'"properties": {'+$nl`
        +$______4tab______+'"view": "'+$view+'",'+$nl`
        +$______4tab______+'"stat": "'+$stat+'",'+$nl`
        +$______4tab______+'"period": '+$period+','+$nl`
        +$______4tab______+'"stacked": '+$stacked+','+$nl`
        +$______4tab______+'"yAxis": {'+$nl`
        +$________5tab________+'"left": {'+$nl`
        +$__________6tab__________+'"min": 0,'+$nl`
        +$labelString`
        +$__________6tab__________+'"showUnits": false'+$nl`
        +$________5tab________+'}'+$nl`
        +$______4tab______+'},'+$nl`
        +$______4tab______+'"region": "'+$metric_region+'",'+$nl`
        +$expression+$nl`
        +$______4tab______+'"title": "RDS IOPS - '+$metric_title+'"'+','+$nl`
        +$______4tab______+'"annotations":{'+$nl`
        +$________5tab________+'"horizontal":['+$nl`
        +$__________6tab__________+'{'+$nl`
        +$____________7tab____________+'"label":"'+$recordtype+' Max IOPS",'+$nl`
        +$____________7tab____________+'"value":'+$metric_BaselineIops
        if ($metric_BaselineIops -ne $metric_MaximumIops) {
            $widget = $widget`
            +' '+$nl`
            +$__________6tab__________+'},'+$nl`
            +$__________6tab__________+'{'+$nl`
            +$____________7tab____________+'"label":"'+$recordtype+' Burst IOPS",'+$nl`
            +$____________7tab____________+'"value":'+$metric_MaximumIops+' '+$nl`
            +$__________6tab__________+'}'+$nl
        }
        else {
            $widget = $widget`
            +', '+$nl`
            +$____________7tab____________+'"fill": "above"'+$nl`
            +$__________6tab__________+'}'+$nl
        }
        $widget = $widget`
        +$________5tab________+']'+$nl`
        +$______4tab______+'}'+$nl`
        +$____3tab____+'}'+$nl`
        +$__2tab__+'},'+$nl

        $global:width=$global:width+$WidgetWidth

        $expression=''`
        +$______4tab______+'"metrics": ['+$nl`
        +$________5tab________+'[ { "expression": "SUM(METRICS()) / 125000", "label": "Total MB/s", "id": "e1" } ],'+$nl`
        +$________5tab________+'[ "AWS/RDS", "ReadThroughput", "DBInstanceIdentifier", "'+$DBInstanceIdentifier+'", { "label": "rdsvolume", "id": "mr1", "visible": false } ],'+$nl`
        +$________5tab________+'[ "AWS/RDS", "WriteThroughput", "DBInstanceIdentifier", "'+$DBInstanceIdentifier+'", { "label": "rdsvolume", "id": "mw1", "visible": false } ]'+$nl`
        +$______4tab______+'],'

        $labelString = $__________6tab__________+'"label": "MB/s",'+$nl

        $widget = $widget`
        +$__2tab__+'{'+$nl`
        +$____3tab____+'"height": '+$WidgetHeight+','+$nl`
        +$____3tab____+'"width": '+$WidgetWidth+','+$nl`
        +$____3tab____+'"y": '+$global:height+','+$nl`
        +$____3tab____+'"x": '+$global:width+','+$nl`
        +$____3tab____+'"type": "'+$type+'",'+$nl`
        +$____3tab____+'"properties": {'+$nl`
        +$______4tab______+'"view": "'+$view+'",'+$nl`
        +$______4tab______+'"stat": "'+$stat+'",'+$nl`
        +$______4tab______+'"period": '+$period+','+$nl`
        +$______4tab______+'"stacked": '+$stacked+','+$nl`
        +$______4tab______+'"yAxis": {'+$nl`
        +$________5tab________+'"left": {'+$nl`
        +$__________6tab__________+'"min": 0,'+$nl`
        +$labelString`
        +$__________6tab__________+'"showUnits": false'+$nl`
        +$________5tab________+'}'+$nl`
        +$______4tab______+'},'+$nl`
        +$______4tab______+'"region": "'+$metric_region+'",'+$nl`
        +$expression+$nl`
        +$______4tab______+'"title": "RDS Throughput - '+$metric_title+'"'+','+$nl`
        +$______4tab______+'"annotations":{'+$nl`
        +$________5tab________+'"horizontal":['+$nl`
        +$__________6tab__________+'{'+$nl`
        +$____________7tab____________+'"label":"'+$recordtype+' Max Throughput",'+$nl`
        +$____________7tab____________+'"value":'+$metric_BaselineThroughputInMBps
        if ($metric_BaselineThroughputInMBps -ne $metric_MaximumThroughputInMBps) {
            $widget = $widget`
            +' '+$nl`
            +$__________6tab__________+'},'+$nl`
            +$__________6tab__________+'{'+$nl`
            +$____________7tab____________+'"label":"'+$recordtype+' Burst Throughput",'+$nl`
            +$____________7tab____________+'"value":'+$metric_MaximumThroughputInMBps+' '+$nl`
            +$__________6tab__________+'}'+$nl
        }
        else {
            $widget = $widget`
            +', '+$nl`
            +$____________7tab____________+'"fill": "above"'+$nl`
            +$__________6tab__________+'}'+$nl
        }

        $widget = $widget`
        +$________5tab________+']'+$nl`
        +$______4tab______+'}'+$nl`
        +$____3tab____+'}'+$nl`
        +$__2tab__+'},'+$nl

        $global:Json = $global:Json + $widget

    }
    Elseif ($WidgetType -eq 'NetworkIn') {

        $expression=''`
        +$______4tab______+'"metrics": ['+$nl`
        +$________5tab________+'[ { "expression": "((m1/PERIOD(m1)) * 8) / 1024 / 1024 / 1024", "label": "Network In Utilization" } ],'+$nl

        if ($recordtype -eq 'EC2') {
            $expression=$expression`
            +$________5tab________+'[ "AWS/EC2", "NetworkIn", "InstanceId", "'+$instance_id+'", { "label": "NetworkIn", "id": "m1", "visible": false } ]'+$nl
        }
        if ($recordtype -eq 'RDS') {
            $expression=$expression`
            +$________5tab________+'[ "AWS/RDS", "NetworkReceiveThroughput", "DBInstanceIdentifier", "'+$DBInstanceIdentifier+'", { "label": "NetworkReceiveThroughput", "id": "m1", "visible": false } ]'+$nl`
        }

        $expression=$expression+`
        $______4tab______+'],'

        $labelString = $__________6tab__________+'"label": "Gbps",'+$nl
    }
    Elseif ($WidgetType -eq 'NetworkOut') {

        $expression=''`
        +$______4tab______+'"metrics": ['+$nl`
        +$________5tab________+'[ { "expression": "((m1/PERIOD(m1)) * 8) / 1024 / 1024 / 1024", "label": "Network Out Utilization" } ],'+$nl

        if ($recordtype -eq 'EC2') {
            $expression=$expression`
            +$________5tab________+'[ "AWS/EC2", "NetworkOut", "InstanceId", "'+$instance_id+'", { "label": "NetworkOut", "id": "m1", "visible": false } ]'+$nl
        }
        if ($recordtype -eq 'RDS') {
            $expression=$expression`
            +$________5tab________+'[ "AWS/RDS", "NetworkTransmitThroughput", "DBInstanceIdentifier", "'+$DBInstanceIdentifier+'", { "label": "NetworkTransmitThroughput", "id": "m1", "visible": false } ]'+$nl
        }

        $expression=$expression+`
        $______4tab______+'],'

        $labelString = $__________6tab__________+'"label": "Gbps",'+$nl
    }

    IF ([string]::IsNullOrWhiteSpace($global:Json)) { $global:Json = $JsonHeader }

    $widget = $nl`
    +$__2tab__+'{'+$nl`
    +$____3tab____+'"height": '+$WidgetHeight+','+$nl`
    +$____3tab____+'"width": '+$WidgetWidth+','+$nl`
    +$____3tab____+'"y": '+$global:height+','+$nl`
    +$____3tab____+'"x": '+$global:width+','+$nl`
    +$____3tab____+'"type": "'+$type+'",'+$nl`
    +$____3tab____+'"properties": {'+$nl`
    +$______4tab______+'"view": "'+$view+'",'+$nl`
    +$______4tab______+'"stat": "'+$stat+'",'+$nl`
    +$______4tab______+'"period": '+$period+','+$nl`
    +$______4tab______+'"stacked": '+$stacked+','+$nl`
    +$______4tab______+'"yAxis": {'+$nl`
    +$________5tab________+'"left": {'+$nl`
    +$__________6tab__________+'"min": 0,'+$nl`
    +$labelString`
    +$__________6tab__________+'"showUnits": false'+$nl`
    +$________5tab________+'}'+$nl`
    +$______4tab______+'},'+$nl`
    +$______4tab______+'"region": "'+$metric_region+'",'+$nl`
    +$expression+$nl`
    +$______4tab______+'"title": "'+$metric_title+'"'


    IF ($WidgetType -ne 'CPU') {
        if ($recordtype -eq 'EC2') {

        $InstanceEbsInfo = aws ec2 describe-instance-types --instance-types $InstType

            ForEach($val IN ($InstanceEbsInfo | ConvertFrom-Json)) {
                $Val

            }
            $metric_BaselineThroughputInMBps = ($InstanceEbsInfo | ConvertFrom-Json).BaselineThroughputInMBps
            $metric_MaximumThroughputInMBps = ($InstanceEbsInfo | ConvertFrom-Json).MaximumThroughputInMBps
            $metric_BaselineIops = (($InstanceEbsInfo | ConvertFrom-Json).BaselineIops)
            $metric_MaximumIops = (($InstanceEbsInfo | ConvertFrom-Json).MaximumIops)

            if ($volume.VolumeType -eq "gp2") {
                if ($volume.Size -lt 171) { 
                    $volumethroughput = 128 
                }
                elseif ($volume.Size -lt 334) {  
                    $volumethroughput = 250 
                }
                else {
                    $volumethroughput = 250 
                }
                $volumeIops = $volume.iops
            }
            elseif ($volume.VolumeType -eq "gp3") {
                $volumethroughput = $volume.Throughput
                $volumeIops = $volume.iops
            }            
            elseif ($volume.VolumeType -eq "io1") {
                $volumethroughput = ($volume.iops * 16)/1024
                $volumeIops = $volume.iops
            }
            elseif ($volume.VolumeType -eq "io2") {
                if ((($InstanceEbsInfo | ConvertFrom-Json).Hypervisor) -eq 'Nitro') {
                    $volumeIops = $volume.iops
                }
                else {
                    if ($volume.iops -gt 32000) { $volumeIops = 32000 } else { $volumeIops = $volume.iops } 
                }
                if ((($InstanceEbsInfo | ConvertFrom-Json).MaximumIops) -eq 260000) {
                    #Block Express
                    $volumethroughput = 256000
                }
                else {
                    $volumethroughput = $volumeIops * 0.256
                }
            }
            elseif ($volume.VolumeType -eq "sc1") {
                $volumethroughput = 250
                $volumeIops = 250
            }
            elseif ($volume.VolumeType -eq "st1") {
                $volumethroughput = 500
                $volumeIops = 500
            }
        }
        elseif ($recordtype -eq 'RDS') {

            $volumes = $volumes -split '~@~'

            $Inst_Title = $volumes[0]
            $Inst_StorageType = $volumes[1]
            $inst_AllocatedStorage = $volumes[2]
            $inst_rdsIops = $volumes[3]
            $inst_rdsiopsburst = $volumes[4]
            $inst_rdsThroughput = $volumes[5]
            $inst_rdsThroughputburst = $volumes[6]

            $metric_BaselineThroughputInMBps = $inst_rdsThroughput
            $metric_MaximumThroughputInMBps = $inst_rdsThroughputburst  
            $metric_BaselineIops = $inst_rdsIops
            $metric_MaximumIops = $inst_rdsiopsburst       
        }
    }

    if ($WidgetType -eq 'EBS-IOPS') {
        $widget = $widget`
        +','+$nl`
        +$______4tab______+'"annotations":{'+$nl`
        +$________5tab________+'"horizontal":['+$nl`
        +$__________6tab__________+'{'+$nl

        $widget = $widget`
        +$____________7tab____________+'"label":"'+$recordtype+' Max IOPS",'+$nl`
        +$____________7tab____________+'"value":'+$metric_BaselineIops
        if ($metric_BaselineIops -ne $metric_MaximumIops) {
            $widget = $widget`
            +' '+$nl`
            +$__________6tab__________+'},'+$nl`
            +$__________6tab__________+'{'+$nl`
            +$____________7tab____________+'"label":"'+$recordtype+' Burst IOPS",'+$nl`
            +$____________7tab____________+'"value":'+$metric_MaximumIops+' '+$nl`
            +$__________6tab__________+'}'+$nl
        }
        else {
            $widget = $widget`
            +', '+$nl`
            +$____________7tab____________+'"fill": "above"'+$nl`
            +$__________6tab__________+'}'+$nl
        }

        $widget = $widget`
        +$________5tab________+']'+$nl`
        +$______4tab______+'}'+$nl
    }
    elseif ($WidgetType -like 'EBS-IOPS-Detail') {

        $widget = $widget`
        +','+$nl`
        +$______4tab______+'"annotations":{'+$nl`
        +$________5tab________+'"horizontal":['+$nl`
        +$__________6tab__________+'{'+$nl`
        +$____________7tab____________+'"label":"Volume Max IOPS",'+$nl`
        +$____________7tab____________+'"value":'+$VolumeIops+','+$nl`
        +$____________7tab____________+'"fill": "above"'+$nl`
        +$__________6tab__________+'}'+$nl`
        +$________5tab________+']'+$nl`
        +$______4tab______+'}'+$nl
    }
    elseif ($WidgetType -eq 'EBS-Throughput') {

        $widget = $widget`
        +','+$nl`
        +$______4tab______+'"annotations":{'+$nl`
        +$________5tab________+'"horizontal":['+$nl`
        +$__________6tab__________+'{'+$nl`
        +$____________7tab____________+'"label":"'+$recordtype+' Max Throughput",'+$nl`
        +$____________7tab____________+'"value":'+$metric_BaselineThroughputInMBps
        if ($metric_BaselineThroughputInMBps -ne $metric_MaximumThroughputInMBps) {
            $widget = $widget`
            +' '+$nl`
            +$__________6tab__________+'},'+$nl`
            +$__________6tab__________+'{'+$nl`
            +$____________7tab____________+'"label":"'+$recordtype+' Burst Throughput",'+$nl`
            +$____________7tab____________+'"value":'+$metric_MaximumThroughputInMBps+' '+$nl`
            +$__________6tab__________+'}'+$nl
        }
        else {
            $widget = $widget`
            +', '+$nl`
            +$____________7tab____________+'"fill": "above"'+$nl`
            +$__________6tab__________+'}'+$nl
        }

        $widget = $widget`
        +$________5tab________+']'+$nl`
        +$______4tab______+'}'+$nl
    }
    elseif ($WidgetType -like 'EBS-Throughput-Detail') {

        $widget = $widget`
        +','+$nl`
        +$______4tab______+'"annotations":{'+$nl`
        +$________5tab________+'"horizontal":['+$nl`
        +$__________6tab__________+'{'+$nl`
        +$____________7tab____________+'"label":"Volume Max Throughput",'+$nl`
        +$____________7tab____________+'"value":'+$volumethroughput+','+$nl`
        +$____________7tab____________+'"fill": "above"'+$nl`
        +$__________6tab__________+'}'+$nl`
        +$________5tab________+']'+$nl`
        +$______4tab______+'}'+$nl
    }   
    else {
        $widget = $widget`
        +$nl
    }

    $widget = $widget`
    +$____3tab____+'}'+$nl`
    +$__2tab__+'},'

    $global:Json = $global:Json + $widget

    if ($incX) { 
        if ($global:width+$WidgetWidth -gt (24-$WidgetWidth)) { 
            if ([string]::IsNullOrWhiteSpace($leftPoint)) { $global:width = 0 } else { $global:width = $leftPoint }
            $global:height=$global:height+$WidgetHeight 
            #AddTitleBlock '##'
        } 
        else 
            { $global:width=$global:width+$WidgetWidth }
    }

    if ($incY) {
        $global:height=$global:height+$WidgetHeight 
    }
}

function CreateDashboard {
    Param ([string]$DashboardName)

    IF ($global:Json.Substring(($global:Json.length-1),1) -eq ',') { $global:Json = $global:Json.Substring(0,($global:Json.length-1)) } 

    $global:Json = $global:Json + $JsonFooter

    $UniquePathName = "$DefaultPath\dashboard_"+(New-Guid).guid+".json"

    Out-File -FilePath $UniquePathName -InputObject $global:Json -Encoding ASCII -Force

    $global:Json

    aws cloudwatch put-dashboard --dashboard-name $DashboardName --dashboard-body "file://$UniquePathName" --profile $global:PS_Profile
}

function Main {
    Param (
        [string]$DashboardName, 
        [string]$TagFilter, 
        [string]$RegionFilter = 'us-east-1',
        $IncludeEC2 = $True, 
        $IncludeRDS = $False, 
        $IncludeFSx = $False
    )

    if ([string]::IsNullOrWhiteSpace($TagFilter)) {
        Write-Host 'No Tag defined, Exiting!'
        Exit
    }

    if (!([string]::IsNullOrWhiteSpace($RegionFilter))) { $global:RegionFilter = $RegionFilter }

    if ([string]::IsNullOrWhiteSpace($DashboardName)) { $DashboardName = $TagFilter }

    $regionlist = aws ec2 describe-regions  --query 'Regions[].RegionName' --output json | ConvertFrom-Json

    $instances = @()
    $rdsinstances = @()
    $fsxWinstances = @()
    $fsxNinstances = @()

    # Load instances into Array
    ForEach ($region in $regionlist) {

        if ($IncludeEC2) {    
            $result = $null
            $result = aws ec2 describe-instances --filters "Name=tag-key,Values=$TagFilter" --query 'Reservations[*].Instances[*].{InstanceType:InstanceType,AZ:Placement.AvailabilityZone,Instanceid:InstanceId,Monitoring:Monitoring,Name:Tags[?Key==`Name`]|[0].Value}' --profile $global:PS_Profile --region $region --output json | ConvertFrom-Json

            if (!([string]::IsNullOrWhiteSpace($result))) {
                $instances += $result 
            }
        }

        if ($IncludeRDS) {   
            $result = $null
            $result = aws rds describe-db-instances --filters Name=engine,Values='sqlserver-ee,sqlserver-se,sqlserver-web,sqlserver-ex' --query 'DBInstances[*].{DBInstanceIdentifier:DBInstanceIdentifier,DBInstanceClass:DBInstanceClass,AllocatedStorage:AllocatedStorage,MaxAllocatedStorage:MaxAllocatedStorage,StorageType:StorageType,StorageThroughput:StorageThroughput,ReadReplicaDBInstanceIdentifiers:ReadReplicaDBInstanceIdentifiers,TagList:TagList,AvailabilityZone:AvailabilityZone,Iops:Iops}' --profile $global:PS_Profile --region $region --output json | ConvertFrom-Json

            #if (!([string]::IsNullOrWhiteSpace($result))) {
            if ($result.count -gt 0) {
                ForEach ($rds in $result) {
                    ForEach ($tag in $rds.taglist) {
                        if ($tag.key -eq $TagFilter) { 
                            $rdsinstances += $rds
                        }
                    }
                }
            }
        }

        if ($IncludeFSx) {
            $result = $null
            $result =  aws fsx describe-file-systems  --profile $global:PS_Profile --region $region  --output json | ConvertFrom-Json   #--query 'FileSystems[*].[FileSystemId,FileSystemType,StorageCapacity,ThroughputCapacity,Iops,TagList]'

            if (!([string]::IsNullOrWhiteSpace($result))) {
                ForEach ($fsx in $result.FileSystems) {
                    ForEach ($tag in $fsx.tags) {
                        if ($tag.key -eq $TagFilter) { 
                            if ($fsx.FileSystemType -eq 'WINDOWS') {
                                $fsxWinstances += $fsx
                            }
                            elseif ($fsx.FileSystemType -eq 'ONTAP')  {
                                $fsxNinstances += $fsx
                            }
                        }
                    }
                }
            }
        }
    }

    if ($IncludeEC2) { 
        [string[]]$instancearray = @()

        ForEach ($instance in $instances) {
           $str = $instance.Name+'~@~'+$instance.InstanceType+'~@~'+$instance.AZ+'~@~'+$instance.Instanceid+'~@~'+$instance.Monitoring
           $instancearray += $Str 
        }
        $SortedInstances = $instancearray | Sort
    }

    if ($IncludeEC2) { 
        ForEach ($instance in $SortedInstances) {
            ##CPU
 
            $Instance = $Instance -split '~@~'

            $InstType = $instance[1]
            $inst_id = $instance[3]
            $inst_name = $instance[0]
            $inst_region = ($instance[2]).ToString().Substring(0,($instance[2]).length-1)
            $inst_monitoring = $instance[4]

            $w_data = @()

            if ([string]::IsNullOrWhiteSpace($inst_name)) { 
                $w_data += "title:CPU - "+$inst_id
            }
            else {
                $w_data += "title:CPU - "+$inst_name+" ("+$inst_id+")"
            }
            $w_data += "instanceid:"+$inst_id
            $w_data += 'region:'+$inst_region
            $w_data += 'recordtype:EC2'

            AddWidget $w_data 'CPU' $True $False 

            if ($IncludeFSx) {
                Write-host 'fsx'
            }
        }    
    }
    
    if ($IncludeRDS) {  
        ForEach ($rdsinstance in $rdsinstances) {

            $inst_region = ($rdsinstance.AvailabilityZone).ToString().Substring(0,($rdsinstance.AvailabilityZone).length-1) 

            $w_data = @()

            $w_data += "title:CPU - "+$rdsinstance.DBInstanceIdentifier

            $w_data += "DBInstanceIdentifier:"+$rdsinstance.DBInstanceIdentifier
            $w_data += 'region:'+$inst_region
            $w_data += 'recordtype:RDS'

            AddWidget $w_data 'CPU' $True $False  
        }
    }

    AddTitleBlock '## EBS Storage Utilization\n' 1

    if ($IncludeEC2) {  
        ForEach ($instance in $SortedInstances) {
            ##EBS

            $Instance = $Instance -split '~@~'

            $InstType = $instance[1]
            $inst_id = $instance[3]
            $inst_name = $instance[0]
            $inst_region = ($instance[2]).ToString().Substring(0,($instance[2]).length-1)
            $inst_monitoring = $instance[4]

            $InstanceEbsInfo = aws ec2 describe-instance-types --instance-types $InstType --query "InstanceTypes[*].EbsInfo[].EbsOptimizedInfo[].{MaximumIops:MaximumIops,MaximumThroughputInMBps:MaximumThroughputInMBps,BaselineThroughputInMBps:BaselineThroughputInMBps,BaselineIops:BaselineIops,networkperformance:networkperformance,Hypervisor:Hypervisor}" --profile $global:PS_Profile --region $inst_region


            $InstanceEbsInfo = aws ec2 describe-instance-types --instance-types $InstType --query "InstanceTypes[*].[Hypervisor, EbsInfo[*].EbsOptimizedInfo[].[MaximumIops,MaximumThroughputInMBps,BaselineThroughputInMBps,BaselineIops, NetworkInfo[].[NetworkPerformance] ]" --profile $global:PS_Profile --region $inst_region

            



            AddTitleBlock "## EC2 IOPS - ($inst_name) - $inst_id" 1
                
            $volumes = aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=$inst_id --query "Volumes[*].{VolumeId:VolumeId,VolumeType:VolumeType,Size:Size,Iops:Iops,Throughput:Throughput}" --profile $global:PS_Profile --region $inst_region --output json | ConvertFrom-Json

            $w_data = @()

            if ([string]::IsNullOrWhiteSpace($inst_name)) { 
                $w_data += "title:EC2 IOPS Storage Utilization - "+$inst_id
            }
            else {
                $w_data += "title:EC2 IOPS Storage Utilization - "+$inst_name+" ("+$inst_id+")"
            }
            $w_data += "instanceid:"+$inst_id
            $w_data += "height:8"
            $w_data += "width:8"
            $w_data += 'stat:Sum'
            $w_data += 'region:'+$inst_region
            $w_data += 'recordtype:EC2'

            AddWidget $w_data 'EBS-IOPS' $True $False $volumes 0 $InstanceEbsInfo

            ForEach ($volume in $volumes) {
                $w_data = @()
                $w_data += "title:EBS IOPS - ("+$inst_name+") - "+$volume.VolumeId
                $w_data += 'stat:Sum'
                $w_data += 'region:'+$inst_region
                $w_data += 'recordtype:EC2'
                AddWidget $w_data 'EBS-IOPS-Detail' $True $False $volume 8 $InstanceEbsInfo
            }
            $global:width = 0


            if ($IncludeFSx) {
                Write-host 'fsx'
            }
        }
    }

    
    if ($IncludeRDS) {   
        ForEach ($rdsinstance in $rdsinstances) {
            $inst_region = ($rdsinstance.AvailabilityZone).ToString().Substring(0,($rdsinstance.AvailabilityZone).length-1) 

            $InstanceEbsInfo = aws ec2 describe-instance-types --instance-types (($rdsinstance.DBInstanceClass).replace('db.','')).ToString() --query "InstanceTypes[*].EbsInfo[].EbsOptimizedInfo[].{MaximumIops:MaximumIops,MaximumThroughputInMBps:MaximumThroughputInMBps,BaselineThroughputInMBps:BaselineThroughputInMBps,BaselineIops:BaselineIops,networkperformance:networkperformance}" --profile $global:PS_Profile --region $inst_region

            $titleString = "## RDS IOPS - "+$rdsinstance.DBInstanceIdentifier
            AddTitleBlock -Title $titleString -Titleheight 1

            if ($rdsinstance.StorageType -eq 'gp2') {
                if ($rdsinstance.AllocatedStorage -le 33.33) {
                    $rdsIops = 100 
                }
                elseif ($rdsinstance.AllocatedStorage -lt 5334) {
                    $rdsIops = $rdsinstance.AllocatedStorage * 3 
                }
                else {
                    $rdsIops = 16000
                }
                if (($rdsinstance.AllocatedStorage -lt 1024) -and ($rdsiops -le 3000)) {
                    $rdsiopsburst = 3000
                }
                else {
                    $rdsiopsburst = $rdsiops
                }
            }
            elseif ($rdsinstance.StorageType -eq 'gp3') {
                $rdsIops = $rdsinstance.iops 
            }
            elseif ($rdsinstance.StorageType -eq 'io1') {
                $rdsIops = $rdsinstance.iops 
            }

            if ($rdsinstance.StorageType -eq 'gp2') {
                if ($rdsinstance.AllocatedStorage -lt 170) {
                    $rdsThroughput = 128 
                    $rdsThroughputburst = 128
                }
                elseif ($rdsinstance.AllocatedStorage -lt 334) {
                    $rdsThroughput = 128
                    $rdsThroughputburst = 250
                }
                else {
                    $rdsThroughput = 250
                    $rdsThroughputburst = 250
                }
            }
            elseif ($rdsinstance.StorageType -eq 'gp3') {
                $rdsThroughput = $rdsinstance.StorageThroughput 
                $rdsThroughputburst = $rdsinstance.StorageThroughput 
            }
            elseif ($rdsinstance.StorageType -eq 'io1') {
                $rdsThroughput = $rdsinstance.StorageThroughput 
                $rdsThroughputburst = $rdsinstance.StorageThroughput 
            }

            $volumes = "RDS-Volume ("+$rdsinstance.StorageType+")"+'~@~'+$rdsinstance.StorageType+'~@~'+$rdsinstance.AllocatedStorage+'~@~'+$rdsIops+'~@~'+$rdsiopsburst+'~@~'+$rdsThroughput+'~@~'+$rdsThroughputburst

            $w_data = @()

            $w_data += "title:"+$rdsinstance.DBInstanceIdentifier

            $w_data += "DBInstanceIdentifier:"+$rdsinstance.DBInstanceIdentifier
            $w_data += "height:8"
            $w_data += "width:8"
            $w_data += 'stat:Sum'
            $w_data += 'period:60'
            $w_data += 'region:'+$inst_region
            $w_data += 'recordtype:RDS'

            AddWidget $w_data 'RDS-Storage' $True $False $volumes 0 $InstanceEbsInfo
        }
        $global:width = 0
    }

    if ($IncludeEC2) { 
        ForEach ($instance in $SortedInstances) {
            ##EBS

            $Instance = $Instance -split '~@~'

            $InstType = $instance[1]
            $inst_id = $instance[3]
            $inst_name = $instance[0]
            $inst_region = ($instance[2]).ToString().Substring(0,($instance[2]).length-1)
            $inst_monitoring = $instance[4]

            $InstanceEbsInfo = aws ec2 describe-instance-types --instance-types $InstType --query "InstanceTypes[*].EbsInfo[].EbsOptimizedInfo[].{MaximumIops:MaximumIops,MaximumThroughputInMBps:MaximumThroughputInMBps,BaselineThroughputInMBps:BaselineThroughputInMBps,BaselineIops:BaselineIops,networkperformance:networkperformance}" --profile $global:PS_Profile --region $inst_region

            AddTitleBlock "## EC2 Throughput - ($inst_name) - $inst_id" 1
                
            $volumes = aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=$inst_id --query "Volumes[*].{VolumeId:VolumeId,VolumeType:VolumeType,Size:Size,Iops:Iops,Throughput:Throughput}" --profile $global:PS_Profile --region $inst_region --output json | ConvertFrom-Json

            $w_data = @()

            if ([string]::IsNullOrWhiteSpace($inst_name)) { 
                $w_data += "title:EBS Throughput Storage Utilization - "+$inst_id
            }
            else {
                $w_data += "title:EBS Throughput Storage Utilization - "+$inst_name+" ("+$inst_id+")"
            }
            $w_data += "instanceid:"+$inst_id
            $w_data += "height:8"
            $w_data += "width:8"
            $w_data += 'stat:Sum'
            $w_data += 'region:'+$inst_region
            $w_data += 'recordtype:EC2'

            AddWidget $w_data 'EBS-Throughput' $True $False $volumes 0 $InstanceEbsInfo

            ForEach ($volume in $volumes) {
                $w_data = @()
                $w_data += "title:EBS Throughput - ("+$inst_name+") - "+$volume.VolumeId
                $w_data += 'stat:Sum'
                $w_data += 'region:'+$inst_region
                $w_data += 'recordtype:EC2'
                AddWidget $w_data 'EBS-Throughput-Detail' $True $False $volume 8 $InstanceEbsInfo
            }
            $global:width = 0


            if ($IncludeFSx) {
            Write-host 'fsx'
            }


        }
    }

  #  if ($IncludeRDS) {   
  #      ForEach ($rdsinstance in $rdsinstances) {
  #          $inst_region = ($rdsinstance.AvailabilityZone).ToString().Substring(0,($rdsinstance.AvailabilityZone).length-1) 
  #
  #          $InstanceEbsInfo = aws ec2 describe-instance-types --instance-types (($rdsinstance.DBInstanceClass).replace('db.','')).ToString() --query "InstanceTypes[*].EbsInfo[].EbsOptimizedInfo[].{MaximumIops:MaximumIops,MaximumThroughputInMBps:MaximumThroughputInMBps,BaselineThroughputInMBps:BaselineThroughputInMBps,BaselineIops:BaselineIops}" --profile $global:PS_Profile --region $inst_region
  #
  #          $titleString = "## RDS Throughput - "+$rdsinstance.DBInstanceIdentifier
  #          AddTitleBlock $titleString 1
  #
  #          if ($rdsinstance.StorageType -eq 'gp2') {
  #              if ($rdsinstance.AllocatedStorage -lt 170) {
  #                  $rdsThroughput = 128 
  #                  $rdsThroughputburst = 128
  #              }
  #              elseif ($rdsinstance.AllocatedStorage -lt 334) {
  #                  $rdsThroughput = 128
  #                  $rdsThroughputburst = 250
  #              }
  #              else {
  #                  $rdsThroughput = 250
  #                  $rdsThroughputburst = 250
  #              }
  #          }
  #          elseif ($rdsinstance.StorageType -eq 'gp3') {
  #              $rdsThroughput = 0
  #              $rdsThroughputburst = 0
  #          }
  #          elseif ($rdsinstance.StorageType -eq 'io1') {
  #              $rdsThroughput = 0
  #              $rdsThroughputburst = 0
  #          }
  #
  #           $rdsiopsburst = 0
  #           $rdsiopsburst = 0
  #
  #          $volumes = "RDS-Volume ("+$rdsinstance.StorageType+")"+'~@~'+$rdsinstance.StorageType+'~@~'+$rdsinstance.AllocatedStorage+'~@~'+$rdsIops+'~@~'+$rdsiopsburst+'~@~'+$rdsThroughput+'~@~'+$rdsThroughputburst
  #
  #          $w_data = @()
  #
  #          $w_data += "title:RDS IOPS Storage Utilization - "+$rdsinstance.DBInstanceIdentifier
  #
  #          $w_data += "DBInstanceIdentifier:"+$rdsinstance.DBInstanceIdentifier
  #          $w_data += "height:8"
  #          $w_data += "width:8"
  #          $w_data += 'stat:Sum'
  #          $w_data += 'period:60'
  #          $w_data += 'region:'+$inst_region
  #          $w_data += 'recordtype:RDS'
  #
  #          AddWidget $w_data 'EBS-Throughput' $True $False $volumes 0 $InstanceEbsInfo
  #      }
  #      $global:width = 0
  #  }

    AddTitleBlock '## Network Utilization' 1

    if ($IncludeEC2) {   
        ForEach ($instance in $SortedInstances) {
            ##Network
  
            $Instance = $Instance -split '~@~'

            $InstType = $instance[1]
            $inst_id = $instance[3]
            $inst_name = $instance[0]
            $inst_region = ($instance[2]).ToString().Substring(0,($instance[2]).length-1)
            $inst_monitoring = $instance[4]

            $w_data = @()

            if ([string]::IsNullOrWhiteSpace($inst_name)) { 
                $w_data += "title:EC2 Network In Utilization - "+$inst_id
            }
            else {
                $w_data += "title:EC2 Network In Utilization - "+$inst_name+" ("+$inst_id+")"
            }
            $w_data += "instanceid:"+$inst_id
            $w_data += 'region:'+$inst_region
            $w_data += 'recordtype:EC2'
            if ($inst_monitoring -eq '@{State=enabled}') { $w_data += 'period:60' }

            AddWidget $w_data 'NetworkIn' $True $False 

            $w_data = @()

            if ([string]::IsNullOrWhiteSpace($inst_name)) { 
                $w_data += "title:EC2 Network Out Utilization - "+$inst_id
            }
            else {
                $w_data += "title:EC2 Network Out Utilization - "+$inst_name+" ("+$inst_id+")"
            }
            $w_data += "instanceid:"+$inst_id
            $w_data += 'region:'+$inst_region
            $w_data += 'recordtype:EC2'
            if ($inst_monitoring -eq '@{State=enabled}') { $w_data += 'period:60' }

            AddWidget $w_data 'NetworkOut' $True $False 


            if ($IncludeFSx) {
            Write-host 'fsx'
            }
        }
    }

    if ($IncludeRDS) {   
        ForEach ($rdsinstance in $rdsinstances) {

            $inst_region = ($rdsinstance.AvailabilityZone).ToString().Substring(0,($rdsinstance.AvailabilityZone).length-1) 

            $w_data = @()

            $w_data += "title:RDS Network Utilization - "+$rdsinstance.DBInstanceIdentifier

            $w_data += "DBInstanceIdentifier:"+$rdsinstance.DBInstanceIdentifier
            $w_data += 'region:'+$inst_region
            $w_data += 'recordtype:RDS'

            AddWidget $w_data 'NetworkIn' $True $False  

            AddWidget $w_data 'NetworkOut' $True $False  
        }
    }

    CreateDashboard $DashboardName
}

$DefaultPath = "c:\aws\DashboardConfig\"
$DefaultPath = "C:\AWS\_RnD\CloudWatchDashboardAutomation\DashboardConfig\"

IF (!(test-path $DefaultPath)) { New-Item -ItemType Directory -Force -Path $DefaultPath | Out-Null }

$global:Json = ''

$global:PS_Profile = 'isengard'

$global:RegionFilter = ''

$global:height = 0
$global:width = 0

$global:MaxWidgetHeight = 0

$tab_ = '    '
$__2tab__ = $tab_+$tab_
$____3tab____ = $tab_+$tab_+$tab_
$______4tab______ = $tab_+$tab_+$tab_+$tab_
$________5tab________ = $tab_+$tab_+$tab_+$tab_+$tab_
$__________6tab__________ = $tab_+$tab_+$tab_+$tab_+$tab_+$tab_
$____________7tab____________ = $tab_+$tab_+$tab_+$tab_+$tab_+$tab_+$tab_

$nl = "`r`n"

$JsonHeader = '{'+$nl+$tab_+'"widgets": ['

$JsonFooter = $nl+$tab_+']'+$nl+'}'

#Main 'SQL-A' 'SQL-A' 'us-east-2'

#Main 'SQL-Server-On-EC2' 'SQL' 'us-east-2'

$EC2 = $true
$RDS = $true
$FSx = $true

Main -TagFilter 'S3-Demo' -IncludeEC2 $True -IncludeRDS $True -IncludeFSx $False 
#'SQL-FSxN' 'us-east-2' $EC2 $RDS $FSxN $FSxW



#FSxN
#Total throughput (bytes/sec)
#DataReadBytes   FSx • DataReadBytes • FileSystemId: fs-0ef2313ede9ba91ee   Sum  1 Min
#DataWriteBytes  FSx • DataWriteBytes • FileSystemId: fs-0ef2313ede9ba91ee  Sum  1 Min
#Total throughput (bytes/sec)    SUM(METRICS())/PERIOD(m1)    

# Total IOPS (operations/sec)
# DataReadOperations   FSx • DataReadOperations • FileSystemId: fs-0ef2313ede9ba91ee    Sum   1 MIn
# DataWriteOperations  FSx • DataWriteOperations • FileSystemId: fs-0ef2313ede9ba91ee   Sum   1 min
# MetadataOperations   FSx • MetadataOperations • FileSystemId: fs-0ef2313ede9ba91ee    Sum  1 min
# Total IOPS (operations/sec)   SUM(METRICS())/PERIOD(m1)   

# Volumes 
# DataReadBytes     FSx • DataReadBytes • VolumeId: fsvol-092252ceca1ca99a9 • FileSystemId: fs-0ef2313ede9ba91ee    Sum  1 Min
# DataWriteBytes    FSx • DataWriteBytes • VolumeId: fsvol-092252ceca1ca99a9 • FileSystemId: fs-0ef2313ede9ba91ee   Sum  1 Min
# Total throughput (bytes/sec)     SUM(METRICS())/PERIOD(m1)

# DataReadOperations   FSx • DataReadOperations • VolumeId: fsvol-092252ceca1ca99a9 • FileSystemId: fs-0ef2313ede9ba91ee    Sum   1 MIn
# DataWriteOperations  FSx • DataWriteOperations • VolumeId: fsvol-092252ceca1ca99a9 • FileSystemId: fs-0ef2313ede9ba91ee   Sum   1 min
# MetadataOperations   FSx • MetadataOperations • VolumeId: fsvol-092252ceca1ca99a9 • FileSystemId: fs-0ef2313ede9ba91ee    Sum  1 min
# Total IOPS (operations/sec)   SUM(METRICS())/PERIOD(m1)  


#FSxW
#Total throughput (bytes/sec)
#DataReadBytes   FSx • DataReadBytes • FileSystemId: fs-0ef2313ede9ba91ee   Sum  1 Min
#DataWriteBytes  FSx • DataWriteBytes • FileSystemId: fs-0ef2313ede9ba91ee  Sum  1 Min
#Total throughput (bytes/sec)    SUM(METRICS())/PERIOD(m1)   

#Total IOPS (operations/sec)
# DataReadOperations   FSx • DataReadOperations • FileSystemId: fs-0ef2313ede9ba91ee    Sum   1 MIn
# DataWriteOperations  FSx • DataWriteOperations • FileSystemId: fs-0ef2313ede9ba91ee   Sum   1 min
# MetadataOperations   FSx • MetadataOperations • FileSystemId: fs-0ef2313ede9ba91ee    Sum  1 min
# Total IOPS (operations/sec)   SUM(METRICS())/PERIOD(m1)   





