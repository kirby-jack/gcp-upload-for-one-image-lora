#!/bin/bash

#  Useful notes :)
#   1) read -e --- the e option allows the user to use [TAB] to navigate through directories
#   2) use $((string)) to convert to int

######################################################
#                  DEFINE FUNCTIONS                  #
######################################################
remove_trailing_slash() {
  local var="$1"
  if [[ "${var: -1}" == "/" ]]; then
    var="${var%/*}"
  fi
  echo "$var"
}


######################################################
#           CHECK IF GCLOUD IS INSTALLED             #
######################################################
# check if gcloud is installed 
if ! command -v gcloud &> /dev/null
then
    echo "gcloud could not be found, please install gcloud CLI https://cloud.google.com/sdk/docs/install"
    exit 1
fi

######################################################
#                 GET DIRECTORIES                   #
######################################################
gitDirectory=$PWD
cd ~/Desktop
imageDirectory=$PWD
cd $gitDirectory

######################################################
#      USER CONFIRMS DIRECTORY FOR IMAGE FILES       #
######################################################
while true; do
    read -p $'\nWill your images be saved in '$imageDirectory$'? Y or N\n' yn
    case $yn in
        [Yy] )  echo $'\n'"Image directory set to '$imageDirectory'"$'\n'; break;;
        [Nn] )  while true; do 
                    cd; read -e -p $'\n'"Please enter the directory which will contain your images (tip: prepend directory with /)"$'\n' newImageDirectory
                    if [ -d $newImageDirectory ]; then
                        imageDirectory=$newImageDirectory
                        echo $'\n'"Image directory set to '$imageDirectory'"; break;
                    else
                        echo $'\n'"Invalid directory"
                    fi 
                done ;;
        * ) echo $'\nPlease answer Y or N';;
    esac
done

######################################################
#              USER SELECTS GCP PROJECTS             #
######################################################
echo "Loading list of GCP projects..."
gcpProject=$(gcloud compute project-info describe --format="value(name)")
while true; do
    read -p $'\n'"Are you uploading to $gcpProject? Y or N"$'\n' yn
    case $yn in
        [Yy] ) break;;
        [Nn] ) echo $'\n'"Please run 'gcloud init' and connect to your desired project"$'\n'; exit;;
        * )    echo $'\n'"Please answer Y or N";;
    esac
done

######################################################
#              USER SELECTS GCP INSTANCE             #
######################################################
echo $'\n'"Loading list of instances..."
instances=$(gcloud compute instances list --format="value(name, zone, status)")
array=()

# reads each line from instances and puts into an array 
while read LINE; do
    array+=("$LINE")
done <<< "$instances"

# creates a select menu with each array item & if statement validates (noting that ${#array[@]} means array length)
# $REPLY stores the variable selected by user
PS3=$'\n'"Please select your instance with a number only: "
array_length=${#array[@]}
array_length=$((array_length + 1))

select i in "${array[@]}"
do
    if [ $REPLY -lt $array_length ] && [ $REPLY -gt 0 ]
    then
        instance=$i
        echo $'\n'"The following instance will be used: "$'\n'"($REPLY) $instance"$'\n'
        # split selected instance into variables
        IFS=$'\t' read -r instanceName instanceZone instanceStatus <<< "$instance"
        break
    else
        echo $'\n'"Invalid input, please select between 1 and ${#array[@]}"
    fi
done

######################################################
#               SET DEFAULT SETTINGS               #
######################################################
# rename files by removing white spaces
echo $'\n'"DEFAULT SETTINGS"$'\n'
read -p "(Recommended) Do you want to rename uploaded image files by replacing white spaces with underscores '_' e.g., change 'test test.png' to 'test_test.png'? Y or N"$'\n' yn
while true 
do
    case $yn in 
        [Yy] ) configRenameWhiteSpace="Y"; break;;
        [Nn] ) configRenameWhiteSpace="N"; break;;
        *    ) echo $'\n'"Please answer Y or N"; 
    esac
done

# rename files by appending with image resolution
read -p $'\n'"(Recommended) Do you want rename your image file by appending with image resolution."$'\n'"e.g., test_test.png becomes test_test_512x768.png? Y or N"$'\n' yn
while true 
do 
    case $yn in
        [Yy] ) configRenameResolution="Y"; break;;
        [Yy] ) configRenameResolution="N"; break;;
        *    ) echo $'\n'"Please answer Y or N"; 
    esac
done


######################################################
#               SET GCP DIRECTORIES                  #
######################################################

read -e -p $'\n'"Please enter your full GCP directory path which will contain your lora image folders: "$'\n' gcpParentLoraFolders
gcpParentLoraFolders=$(remove_trailing_slash "$gcpParentLoraFolders")
read -e -p $'\n'"Please enter your full GCP directory path which will contain your lora .toml configuration settings: "$'\n' gcpParentLoraConfigFolders
gcpParentLoraConfigFolders=$(remove_trailing_slash "$gcpParentLoraConfigFolders")
read -e -p $'\n'"Please enter your full GCP directory path to kohya-ss' 'sd-scripts': "$'\n' gcpKohyaSdScripts
gcpKohyaSdScripts=$(remove_trailing_slash "$gcpKohyaSdScripts")
read -e -p $'\n'"Please enter your full GCP directory where your lora will be saved: "$'\n' gcpOutput_Dir
gcpOutput_Dir=$(remove_trailing_slash "$gcpOutput_Dir")
read -e -p $'\n'"Please enter the full GCP path to the pre-trained model you will be using: "$'\n' gcpModel
gcpModel=$(remove_trailing_slash "$gcpModel")


######################################################
#            WRITE VARIABLES TO CONFIG               #
######################################################

echo "imageDirectory=$imageDirectory" > config.txt
echo "gitDirectory=$gitDirectory" >> config.txt
echo "instanceName=$instanceName" >> config.txt
echo "instanceZone=$instanceZone" >> config.txt
echo "instanceStatus=$instanceStatus" >> config.txt
echo "configRenameWhiteSpace=$configRenameWhiteSpace" >> config.txt
echo "configRenameResolution=$configRenameResolution" >> config.txt
echo "gcpParentLoraFolders=$gcpParentLoraFolders" >> config.txt
echo "gcpParentLoraConfigFolders=$gcpParentLoraConfigFolders" >> config.txt
echo "gcpKohyaSdScripts=$gcpKohyaSdScripts" >> config.txt
echo "gcpOutput_Dir=$gcpOutput_Dir" >> config.txt
echo "gcpModel=$gcpModel" >> config.txt

echo $'\n'"Setup complete, you can now run 'upload.sh'"$'\n'