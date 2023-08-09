# BeagleBone AI 64 Tutorial

A step by step introduction to programming the [BeagleBone AI 64 Tutorial](https://www.beagleboard.org/boards/beaglebone-ai-64) board,
especially with DSP target in mind.

## Install

In order to have all compilers and linkers from TI code generation tools at hands, but also the remoteproc headers, first install following packages:

```
sudo apt install ti-c7000-cgt-v2.1 ti-c6000-cgt-v8.3 ti-pru-cgt-v2.3 ti-pru-software linux-headers-$(uname -r)
```

## Tutorial Steps

0. [simplest PRU software](./example-00-pru)
1. [Simple Hello Worl with remoteproc trace](./example-01-pru-hello)
2. [Simplest DSP firmware](./example-02-c6x-dsp/)

## Inspiration

* https://www.glennklockwood.com/embedded/
* https://markayoder.github.io/PRUCookbook/
* https://github.com/RoSchmi/Beaglebone-PRU-RPMsg-HelloWorld
* https://solidmodeling.calliope.us/index.php/2016/09/11/beaglebone-remoteproc-hello-world/
* https://github.com/PierrickRauby/PRU-RPMsg-Setup-BeagleBoneBlack/blob/master/PRU%20Rpmsg%20documentation.pdf

