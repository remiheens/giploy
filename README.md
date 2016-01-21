# giploy

giploy is another script to deploy git master branch on remote server. The particularity of giploy is that it don't create tag or symbolic link on remote server like capistrano, so you don't have to extract or copy  users uploaded files from your directory after deployement. It pull source from develop branch on a git repository and create a release branch to bump the version and merge on master before pushing on remote server. It works like [git-flow](http://jeffkreeftmeijer.com/2010/why-arent-you-using-git-flow/) works. 

It very usefull if you don't want to hook a push on master to deploy automatically but you want to manage your deployment schedulation.

```
Deployment server ------- www1
                     \--- www2
```

## Install 
Download the giploy.sh and giploy.conf
```
$ vim giploy.conf
$ chmod +x giploy.sh
$ ./giploy.sh -h
```

## Add remote server (manually)

### on remote server

Create empty git repository
```
$ mkdir -p /home/<user>/<project>.git
$ cd /home/<user>/<project>.git
$ git init --bare
```

Create the hook that checkout pushed branch
```
$ vim hooks/post-receive
#!/bin/sh 
GIT_WORK_TREE=/var/www/<project> git checkout -f
```

Make sure that your hook have correct rights
```
$ chmod +x hooks/post-receive
```

### on deployment/dev server

In your repository path , you have to add a remote server to use this script.
```
$ cd <repository-path>
$ git remote add production ssh://<website.com>/home/<user>/<project>.git
```

Do an initial push, that setup the master branch
```
$ git push production +master:refs/heads/master
```

So, you've ready to use this remote server and add it to giploy.conf

Enjoy

## Share SSH Key with remote server

If you have many remote server, you probably want to share ssh key to avoid password typing for each server.
Go to your deployement/dev server and type this command ```ssh-keygen```if you don't have a ```~/.ssh/id_rsa``` file
Now, it's time to copy your public key to your remote server : 
```
$ ssh-copy-id <user>@<website.com>
```
To validate installation, try to login to your remote server and if it don't ask for password, ssh key was correctly installed.
