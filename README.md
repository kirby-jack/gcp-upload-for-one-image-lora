# gcp-upload-for-one-image-lora

## Background
This bash script was developed to expedite the process for training single image loras using kohya-ss in GCloud VMs.

**Example**

Let's say you have an image named `test test.png` with a resolution of `512x768`, and you want train a lora with the following settings:
* `repeats: 20`
* `class name: testClass`
* `instance prompt: shs`
* a `.txt` file describing the image

(**note**: you can change further settings if desired by updating the config files, however the settings I have seem to work well)

After you run the script:

1. Your image will be renamed by replacing whitespaces with underscores and appending the name with the images resolution. For example, `test test.png` will become `test_test_512x768.png` (this behaviour can be turned off with the `setup.sh` script). 
2. The following folders will be uploaded to your GCP VM (**note**: the folder path is set with the `setup.sh` script)

```
folder path: '~/kohya_ss/dataset/images/'
| –– test_test_512x768
|   |
|   |–– 20_shs testClass
|      |–– test_test_512x768.png
|      |–– test_test_512x768.txt


folder path - '~/kohya_ss/config_files/lora_configs/'
| –– test_test_512x768_toml
|   |
|   |–– test_test_512x768.toml
|   |–– test_test_512x768_dataset.toml
```

2. A script will be generated to start training your lora, for example mine looked like:
```
python3 /home/jackkirby/kohya_ss/sd-scripts/sdxl_train_network.py --config_file=/home/jackkirby/kohya_ss/config_files/lora_configs/test_test_2152x674_toml/test_test_2152x674.toml --dataset_config=/home/jackkirby/kohya_ss/config_files/lora_configs/test_test_2152x674_toml/test_test_2152x674_dataset.toml
```


## Usage
1. `git clone` the repository
2. run `./setup.sh` (you only need to do this once, or whenever you want to change your project, instance, or default settings)
3. run `./upload.sh`

To change additional lora settings, update `base_config.toml` then re-run `./upload.sh`. Please **do not** change variables that begin with `$`.

## Contact
If you have any questions or would like additional features in this script, please feel free to contact me on LinkeIn https://www.linkedin.com/in/kirby-jack/
