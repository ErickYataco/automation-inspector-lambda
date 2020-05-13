const AWS = require('aws-sdk');

const ssm       = new AWS.SSM();
const inspector = new AWS.Inspector();


exports.handler = async (event, context) => {

    try {
        
        console.log('event: ',event)

        var message             = event['Records'][0]['SNS']['Message']
        
        console.log('message: ',message)

        var notificationType    = event['detail']

        if (notificationType!="FINDING_REPORTED"){
            console.log('Skiping notification that is not a new finding: ',notificationType)
            return true
        }

        const findingArn =message.finding
        console.log('Finding Arn:',findingArn)

        var params = {
            findingArns:[findingArn]
        }

        const response = await inspector.describeFindings(params).promise()

        const finding = response.findings[0]

        const title = finding.title

        if (title == "Unsupported Operating System or Version") {
            console.log('Skipping finding: ', title)
            return true
        }

        if (title == "No potential security issues found") {
            console.log('Skipping finding: ', title)
            return true
        }
        
        const service = finding.service

        if (service != "Inspector") {
            console.log('Skipping finding: ', service)
            return true
        }

        const cveId=''
        for ( attribute of finding.attributes) {
            if (attribute.key=="CVE_ID"){
                cveId = attribute.value
            }
            break
        }

        console.log('CVE ID', cveId)

        if (cveId==''){
            console.log('skipping non-CVE finding')
            return true
        }
      
        const assetType = finding.assetType

        if (assetType != "ec2-instance") {
            console.log('Skipping non-EC2-instance asset type: ', assetType)
            return true
        }

        const instanceId=finding.assetAttributtes.agentId
        console.log('Instance Id ', instanceId)
        if (!instanceId.startsWith('i-')) {
            console.log('Invalid Instance Id: ', instanceId)
            return true
        }

        params = {
            InstanceInformationFilterList: [
                {
                  key: 'InstanceIds', 
                  valueSet: [ 
                    instanceId,
                  ]
                },
            ],
            MaxResults:50
        }

        response = await ssm.describeInstanceInformation(params).promise()

        instanceInfo = response.InstanceInformationFilterList[0]

        console.log('SSM status of instance: ',instanceInfo.PingStatus)
        console.log('OS type: ',instanceInfo.PlatformType)
        console.log('OS name: ',instanceInfo.PlatformName)
        console.log('OS version: ',instanceInfo.PlatformVersion)

        if (instanceInfo.PingStatus != "Online") {
            console.log('SSM agent for this instance its not online: ', instanceInfo.PingStatus)
            return true
        }

        if (instanceInfo.PlatformType != "Linux") {
            console.log('Skipping non-linux platform: ', instanceInfo.PlatformType)
            return true
        }

        var command 
        if (instanceInfo.PlatformName.startsWith('Ubuntu')){
            command = "apt-get update -qq -y; apt-get upgrade -y"
        } else if (instanceInfo.PlatformName.startsWith('Ubuntu')){
            command = "yum update -q -y; yum upgrade -y"
        } else {
            console.log('Unsupported Linux distribution: ', instanceInfo.PlatformName)
            return true
        }
        console.log('command line to execute: ',command)

        params = {
            DocumentName: 'AWS-RunShellScript',
            Comment: 'AWS-RunShellScript',
            InstanceIds: [
                instanceId,
            ],
            Parameters: {
                'commands': [
                    command,
                ],
            },
        }

        reponse = await ssm.sendCommand(params).promise()


        console.log('SSM command response: ', response)

        return true

    } catch (error) {

        console.log('error: ',error)

    }

}