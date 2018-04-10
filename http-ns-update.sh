#!env bash
source http.sh


index_route() {
	Response[Status]="200 OK"
	Response[Body]="<h1>It works!</h1>
	<p>
	Send nsupdates for http post for /nsupdate path in body commands
	</p>
"
}

nsupdate_route(){
	Response[Status]="200 OK"
	Response[Body]="";
}

http_serve 0.0.0.0 8081 '
	/ index_route
	/detail nsupdate_route
'
