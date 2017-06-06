#!groovy
pipeline {
  agent any
  stages {
    stage('Clean and Prepare') {
      steps {
        script {
          sh ('ls -la')
          // Get User Input
          userInput = input(
            id: 'userInput',
            message: 'Lets build a kernel',
            parameters: [
              [
                $class: 'BooleanParameterDefinition',
                description: '(Re)build kernel?',
                name: 'buildKernel'
              ],
              [
                $class: 'BooleanParameterDefinition',
                description: '(Re)deploy kernel?',
                name: 'deployKernel'
              ],
              [
                $class: 'BooleanParameterDefinition',
                description: 'Configure cmdline and system.conf locally on pi sd card?',
                name: 'localConfigPi'
              ],
              [
                $class: 'BooleanParameterDefinition',
                description: 'Install packages and other rando crap on booted pi?',
                name: 'sshConfigPi'
              ],
              [
                $class: 'FileParameterDefinition',
                description: 'Upload a wpa_supplicant.conf file if you want to configure wireless SSIDs.',
                name: 'wpa_supplicant'
              ],
              [
                $class: 'ChoiceParameterDefinition',
                choices: 'basicRtKernelConfig\nfullRtKernelConfig',
                description: 'Pick between pre-made kernel config files.',
                name: 'kernelConfig'
              ],
              [
                $class: 'ChoiceParameterDefinition',
                choices: 'local\nremote',
                description: 'Pick between cloning local repos or pulling from github.',
                name: 'gitRepoLocation'
              ],
              [
                $class: 'TextParameterDefinition',
                name: 'kernelRepoTag',
                defaultValue: 'raspberrypi-kernel_1.20170405-1',
                description: 'git tag for kernel repo'
              ],
              [
                $class: 'TextParameterDefinition',
                name: 'patchUrl',
                defaultValue: 'https://www.kernel.org/pub/linux/kernel/projects/rt/4.4/older',
                description: 'URL to realtime kernel patch'
              ],
              [
                $class: 'TextParameterDefinition',
                name: 'patchFile',
                defaultValue: 'patch-4.4.50-rt63.patch.gz',
                description: 'kernel patch file name. Should be *.patch.gz'
              ],
              [
                $class: 'TextParameterDefinition',
                name: 'deployPathBoot',
                defaultValue: '/media/cheekymusic/boot',
                description: 'Path to Raspi boot dir.'
              ],
              [
                $class: 'TextParameterDefinition',
                name: 'deployPathLibPrefix',
                defaultValue: '/media/cheekymusic/f2100b2f-ed84-4647-b5ae-089280112716',
                description: 'Path to Raspi lib dir.'
              ],
              [
                $class: 'TextParameterDefinition',
                name: 'toolsRepo',
                defaultValue: '/home/cheekymusic/tools',
                description: 'Local Repopath for kernel tools'
              ],
              [
                $class: 'TextParameterDefinition',
                name: 'kernelRepo',
                defaultValue: '/home/cheekymusic/linux',
                description: 'Local Repopath for kernel'
              ]
            ]
          )
          userInput['deployPathLib'] = "$userInput.deployPathLibPrefix/lib"
          if (userInput['gitRepoLocation'] == 'remote')  {
            userInput['toolsRepo'] = 'https://github.com/raspberrypi/tools.git'
            userInput['kernelRepo'] = 'https://github.com/raspberrypi/linux.git'
          }
          if (userInput['buildKernel']) {
            sh('rm -rf tools linux modules rtkernel')
            sh('git clean -xf')
            sh('git reset --hard')
          } else { echo 'Not cleaning previously built kernel.' }
        }
      }
    }
    stage('Clone') {
      steps {
        script {
          if (userInput['buildKernel']) {
            parallel 'tools':{
              sh("git clone --single-branch $userInput.toolsRepo")
            }, 'kernel':{
              sh("git clone --single-branch $userInput.kernelRepo -b $userInput.kernelRepoTag")
            }
          }
          else { echo 'Using previously pulled repos.' }
        }
      }
    }
    stage('Patch Kernel') {
      steps {
        script {
          if (userInput['buildKernel']) {
            // Move pre-made configs into kernel folder
            sh("mv .$userInput.kernelConfig linux/.config")
            // Patch Kernel code with realtime code
            dir('linux/') {
              sh("wget $userInput.patchUrl/$userInput.patchFile")
              sh("zcat $userInput.patchFile | patch -p1")
            }
          } else { echo 'No need to patch, reusing kernel :)' }
        }
      }
    }
    stage('Build Kernel') {
      steps {
        script {
          if (userInput['buildKernel']) {
            sh('ls -la')
            sh('mkdir modules')
            sh('mkdir -p rtkernel/boot')
            // LETS BUILD A KERNEL!!!
            dir('linux/') {
              sh '''
                source ../jenkins.source
                env
                make zImage modules dtbs -j4
                make modules_install -j4
                ./scripts/mkknlimg ./arch/arm/boot/zImage $INSTALL_MOD_PATH/boot/$KERNEL.img
              '''
            }
          } else { echo 'No need to build kernel :)' }
        }
      }
    }
    stage('Deploy Kernel') {
      steps {
        script {
          if (userInput['deployKernel']) {
            echo("LETS DEPLOY A KERNEL!!!")
            sh("sudo rm -r $userInput.deployPathBoot/overlays/ || true")
            // sh("sudo rm -r $userInput.deployPathLib/firmware/") // do i need this part?
            parallel 'boot':{
              dir('rtkernel/boot/') {
                sh("sudo cp -rd * $userInput.deployPathBoot/")
                sh("sudo touch $userInput.deployPathBoot/ssh") // enables ssh for raspi
              }
            }, 'lib':{
              dir('rtkernel/lib/') {
                sh("sudo cp -dr * $userInput.deployPathLib/")
              }
            }
          } else { echo('Not deploying previously deployed kernel :)') }
        }
      }
    }
    stage('Configure Pi Boot') {
      steps {
        script {
          if (userInput['localConfigPi']) {
            def configureSystemConf = false
            // try catches to catch grep counts without exiting the jenkins script on shell script failure
            ///////////////////////////////
            // system.conf configuration //
            ///////////////////////////////

            try {
              sh("sudo grep -c '<allow own=\"org.freedesktop.ReserveDevice1.Audio1\"/>' $userInput.deployPathLibPrefix/etc/dbus-1/system.conf")
            } catch(e1) { configureSystemConf = true }

            if (configureSystemConf) {
              sh """
  sudo sed -i 's/<\\/busconfig>/  <policy user="pi">\\
      <allow own="org.freedesktop.ReserveDevice1.Audio1"\\/>\\
    <\\/policy>\\
  <\\/busconfig>/' $userInput.deployPathLibPrefix/etc/dbus-1/system.conf
              """
            } else { echo "Already configured system.conf!" }
            ///////////////////////////////
            // cmdline.txt configuration //
            ///////////////////////////////
            def configureCmdlineTxt = false
            try {
              sh("sudo grep -c \"dwc_otg.speed=1 sdhci_bcm2708.enable_llm=0 smsc95xx.turbo_mode=N\" $userInput.deployPathBoot/cmdline.txt")
            } catch(e1) { configureCmdlineTxt = true }

            if (configureCmdlineTxt) {
              sh("sudo sed -i '1s/\$/ dwc_otg.speed=1 sdhci_bcm2708.enable_llm=0 smsc95xx.turbo_mode=N/' $userInput.deployPathBoot/cmdline.txt")
            } else { echo "Already configured cmdline.txt!"}
            ///////////////////////////////////////
            // wpa_supplicant.conf configuration //
            ///////////////////////////////////////
            sh("cat $userInput.wpa_supplicant")

            def configureWpaSupplicant = false
            try {
              sh("sudo grep -ic ssid $userInput.wpa_supplicant")
              configureWpaSupplicant = true
            } catch(e1) { configureWpaSupplicant = false }
            if (configureWpaSupplicant) {
              sh("sudo cp $userInput.wpa_supplicant $userInput.deployPathLibPrefix/etc/wpa_supplicant/wpa_supplicant.conf")
              sh("sudo chmod 600 $userInput.deployPathLibPrefix/etc/wpa_supplicant/wpa_supplicant.conf")
              sh("sudo chown root:root $userInput.deployPathLibPrefix/etc/wpa_supplicant/wpa_supplicant.conf")
            } else { echo "Invalid wpa_supplicant.conf!" }
          } else { echo 'Not doing local pi configs :)' }
        }
      }
    }
    stage('ssh Configure Pi') {
      steps {
        script {
          if (userInput['sshConfigPi']) {
            echo 'Figure out how to ssh...'
          }
          else { echo 'Not ssh-ing to pi to configure anything :)' }
        }
      }
    }
  }
}