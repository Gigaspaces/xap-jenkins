docker run -e JAVA_OPTS=-Duser.timezone=Asia/Jerusalem -d -p 8080:8080 --volume `pwd`/../jenkins_home:/var/jenkins_home --volume `pwd`/../workspaces:/var/workspaces   --volume /home/xap/.ssh:/home/jenkins/.ssh  --volume `pwd`/../m2:/home/jenkins/.m2  --name build-jenkins xap/jenkins

