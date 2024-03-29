    #!/bin/bash
    fileName=`basename "$0"`
    echo running $fileName

    ### PARAMETER
    if [ $(hostname) = "raspi" ]
    then
        serverName="localhost"
        sudo sh -c 'echo 255 > /sys/class/leds/PWR/brightness' # LED ON
    else
        serverName="192.168.1.76"
    fi

    apiUrl=http://${serverName}:8581/api
    username="hendro777"
    password="92iFbtYoEh^Rvfgs"

    ### FUNCTIONS
    function get_bearer_token() {
        bearerTokenResponse=$(
            http --ignore-stdin POST ${apiUrl}/auth/login password=$password username=$username
        )

        token=$(echo $bearerTokenResponse | jq -r .access_token)
        echo $token
    }

    function get_all_accessories() {
        echo $(
            http --ignore-stdin -A bearer -a $token GET ${apiUrl}/accessories
        )
    }

    # $1 must be name of accessory
    function get_accessory() {
        accessoryName=$1
        filter='.[] | select(.serviceName=='"\"${accessoryName}\""')'
        echo $accessoriesResponse | jq '.[] | select(.serviceName=='"\"${accessoryName}\""')'
    }

    # $1 must be JSON of accessory
    function get_accessory_UID() {
        accessoryName=$1
        accessory=$(get_accessory $accessoryName)
        echo $accessory | jq -r .uniqueId
    }

    function toggle_device() {
        accessoryName=$1
        accessory=$(get_accessory $accessoryName)
        accessory_UUID=$(get_accessory_UID $accessoryName)

        type="On"
        declare -i value=$(echo $accessory | jq -r .serviceCharacteristics | jq '.[] | select(.type=="'$type'")' | jq -r .value)
        declare -i newValue=$((($value + 1) % 2))

        http --ignore-stdin -A bearer -a $token PUT ${apiUrl}/accessories/${accessory_UUID} characteristicType="$type" value="$newValue"
    }

    function power_on() {
        accessoryName=$1
        accessory=$(get_accessory $accessoryName)
        accessory_UUID=$(get_accessory_UID $accessoryName)

        type="On"
        newValue="1"

        http --ignore-stdin -A bearer -a $token PUT ${apiUrl}/accessories/${accessory_UUID} characteristicType="$type" value="$newValue"
    }

    function set_brightness() {
        accessoryName=$1
        declare -i newValue=$2
        accessory=$(get_accessory $accessoryName)
        accessory_UUID=$(get_accessory_UID $accessoryName)

        if (( $newValue < 1))
        then 
            newValue=1
        elif (( $newValue > 100)) 
        then
            newValue=100
        fi

        type="Brightness"
        http --ignore-stdin -A bearer -a $token PUT ${apiUrl}/accessories/${accessory_UUID} characteristicType="$type" value:=$newValue
    }

    function change_brightness() {
        accessoryName=$1
        declare -i rate=$2
        accessory=$(get_accessory $accessoryName)
        accessory_UUID=$(get_accessory_UID $accessoryName)

        type="Brightness"
        declare -i value=$(echo $accessory | jq -r .serviceCharacteristics | jq '.[] | select(.type=="'$type'")' | jq -r .value)
        declare -i newValue=$value+$rate

        set_brightness $accessoryName $newValue
    }

    function increase_brightness() {
        accessoryName=$1
        change_brightness $accessoryName 10 
    }

    function decrease_brightness() {
        accessoryName=$1
        change_brightness $accessoryName -10
    }

    ### Preparation
    token=$(get_bearer_token)
    accessoriesResponse=$(get_all_accessories)

    # ### IR REMOTE KEY PRESSED SCRIPT
    action=$1
    accessoryName=$2
    key_pressed=$3

    if [ "$action" == "toggle" ]; 
    then
        toggle_device $accessoryName
    elif [ "$action" == "dec_brightness" ]
    then 
        decrease_brightness $accessoryName
    elif [ "$action" == "inc_brightness" ]
    then 
        increase_brightness $accessoryName
    elif [ "$action" == "min_brightness" ]
    then 
        set_brightness $accessoryName 1
    elif [ "$action" == "max_brightness" ]
    then 
        power_on $accessoryName
        set_brightness $accessoryName 100
    fi

    ### LED OFF
    if [ $(hostname) = "raspi" ]
    then
        serverName="localhost"
        sudo sh -c 'echo 0 > /sys/class/leds/PWR/brightness'
    fi

    echo finishing $fileName
