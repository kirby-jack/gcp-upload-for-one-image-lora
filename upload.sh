#!/bin/bash

######################################################
#         IMPORT VARIABLES AND CONFIGURATION         #
######################################################
if [ -f "config.txt" ]; then
    source config.txt
else
    echo $'\n'"No config file found, please run 'setup.sh' first'"$'\n'
    exit
fi

######################################################
#                USER SELECTS IMAGE                  #
######################################################
cd $imageDirectory

shopt -s nullglob # nullglob - Bash allows filename patterns which match no files to expand to a null string, rather than themselves.
imageFilesArray=(*.{png,jpeg,jpg,pdf})

PS3=$'\n'"Please select your image by typing its number only: "
select i in "${imageFilesArray[@]}"
do
    image=$i
    oldImageName=$image
    break
done


######################################################  # this will depend if the 
#                 CLEAN FILE NAME                    #  # user selected Y
######################################################  # in setup.sh (configRenameWhiteSpace, configRenameResolution in config.txt file)

# replace white space
if [ $configRenameWhiteSpace = "Y" ]; then 
    newImageName=$(echo $image | sed -e "s/ /_/g")
    mv "$image" "$newImageName"; image=$newImageName
fi

# get resolution (this is also needed for the toml file)
resolution=$(file "$image" | cut -d, -f2 | sed -e "s/[[:space:]]x[[:space:]]/x/" | tr -d '[:space:]')
resolution_toml=$(tr 'x' ',' <<< "$resolution")

# append with resolution
if [ $configRenameResolution = "Y" ]; then
    fileName="${image%.*}_$resolution"
    fileType=".${image##*.}" # read up on this for notes https://superuser.com/questions/90057/linux-rename-file-but-keep-extension 
    newImageName="${fileName}${fileType}"
    mv "$image" "$newImageName"; image=$newImageName
fi

echo $'\n'"'$oldImageName' has been renamed to '$image'"$'\n'


######################################################
#             LORA VARIABLES & .txt FILE             #
######################################################

# Get repeats variable
read -p "How many repeats do you want for this image? " repeats

# Get class variable
while true; do
    read -r -p "What is the class name for this image? " class
    if [[ "$class" =~ ^[[:alnum:]]+$ ]]; then
        break
    else
        echo $'\n'"Invalid class name. Please enter a single word. "$'\n'
    fi
done

# Get instance prompt
while true; do
    read -r -p "What is the instance prompt? Recommended to use 'shs': " instancePrompt
    if [[ "$instancePrompt" =~ ^[[:alnum:]]+$ ]]; then
        break
    else
        echo $'\n'"Invalid instance prompt. Please enter a single word. "$'\n'
    fi
done

# Create .txt file
read -p "Enter your lora txt file describing the image (for more than 75 tokens, update the .toml file 'max_token_length' value): " prompt
textFile=${image%.*}.txt
echo "$prompt" > "$textFile"


######################################################
#             CREATE LORA .toml CONFIG               #
######################################################

# Create config toml file
tomlFile=${image%.*}.toml
cat "$gitDirectory/base_config.toml" > $tomlFile

# insert output_name, class_prompt, resolution, sample_prompts into toml
sed -i '' "s/\$output_name/${image%.*}/" $tomlFile # note sed will not replace the word unless it has ''
sed -i '' "s/\$class/$class/" $tomlFile
sed -i '' "s/\$instance_prompt/$instancePrompt/" $tomlFile
sed -i '' "s/\$resolution/$resolution_toml/" $tomlFile
sed -i '' "s,\$output_dir,$gcpOutput_Dir," $tomlFile
sed -i '' "s,\$pretrained_model_name_or_path,$gcpModel," $tomlFile


######################################################
#             MAKE & POPULATE FOLDERS                #
######################################################

# make folder for image & txt 
imageFolder=${image%.*}
loraFolder="${repeats}_$instancePrompt $class"
mkdir "$imageFolder"
mkdir "$imageFolder/$loraFolder"
pathToLoraFolder="$imageFolder/$loraFolder"
cp "$image" "$imageFolder/$loraFolder"
mv "$textFile" "$imageFolder/$loraFolder"

# make folder for toml configs
tomlFolder=${image%.*}_toml
mkdir "$tomlFolder"
mv "$tomlFile" "$tomlFolder" 


######################################################
#         CREATE LORA .toml CONFIG_DATASET           #
######################################################

tomlDatasetFile=${image%.*}_dataset.toml
cat "$gitDirectory/base_dataset_config.toml" > $tomlDatasetFile
# insert image_dir, num_repeats, & resolution into toml
sed -i '' "s/\$resolution/$resolution_toml/" $tomlDatasetFile
sed -i '' "s,\$gcpParentLoraFolders,$gcpParentLoraFolders," $tomlDatasetFile # $image_txt_folder_child contains '/' we can change the delimiter in sed to ',' 
sed -i '' "s,\$pathToLoraFolder,$pathToLoraFolder," $tomlDatasetFile # $image_txt_folder_child contains '/' we can change the delimiter in sed to ',' 
sed -i '' "s/\$repeats/$rep/" $tomlDatasetFile
mv "$tomlDatasetFile" "$tomlFolder"


######################################################
#              UPLOAD TO GCP INSTANCE                #
######################################################

echo -e "\nConnecting to GCP VM...\n"
instanceStatus=$(gcloud compute instances describe "$instanceName" --zone $instanceZone --format="value(status)")

while true; do
    if [ $instanceStatus = "TERMINATED" ]; then
        read -p $'\n'"'$instanceName' status is $instanceStatus. Please start your instance, then click [ENTER]" yn
        instanceStatus=$(gcloud compute instances describe "$instanceName" --zone $instanceZone --format="value(status)")
    else
        echo -e "Connected\n"
        echo -e "\nUploading $imageFolder folder to $gcpParentLoraFolders\n"
        gcloud compute scp --recurse --zone $instanceZone "$imageFolder" $instanceName:$gcpParentLoraFolders
        echo -e "\n$imageFolder successfully uploaded\n"
        echo -e "\nUploading $tomlFolder lora config folder to $gcpParentLoraConfigFolders\n"
        gcloud compute scp --recurse --zone $instanceZone "$tomlFolder" $instanceName:$gcpParentLoraConfigFolders
        echo -e "\n$tomlFolder successfully uploaded\n"
        break;
    fi
done


######################################################
#          CLEAN UP FILES (LEAVE NO TRACE :))        #
######################################################

rm -rf $imageFolder
rm -rf $tomlFolder

# you can now launch
echo "you can now train your lora with:"$'\n'$'\n'"python3 $gcpKohyaSdScripts/sdxl_train_network.py --config_file=$gcpParentLoraConfigFolders/$tomlFolder/$tomlFile --dataset_config=$gcpParentLoraConfigFolders/$tomlFolder/$tomlDatasetFile"$'\n'
