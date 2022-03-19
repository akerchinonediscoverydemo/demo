# One Discovery / Architecture suggestions
### _Demo App_
Structure:
##### OneDiscoveryDemoApi
.NET 5 WebApi project, backend to work with Clickhouse DB. It uses the following library for communication with Clickhouse:
https://github.com/DarkWanderer/ClickHouse.Client
Its possible to:
- add item from JSON to database. 
- generate random items (100 millions+) and insert them to the DB. Estimate the speed of insert.
- search against the DB. Estimate the speed of search.

Install docker, make "docker-compose" a Start Project and run. Open http://localhost:8085 after run.

##### OneDiscoveryDemoUi
Angular project, the simple frontend for OneDiscoveryDemoApi.
`yarn install`
`yarn start`
for standalone run. But it better to run via OneDiscoveryDemoApi to work with backend.

##### CICD
Preinstall before run:
1) Powershell
https://docs.microsoft.com/ru-ru/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2#msi
2) Az CLI
https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli
3) Docker:
https://docs.docker.com/desktop/windows/install/
4) Helm
https://helm.sh/docs/intro/install/
5) Idealy to have Lens:
https://k8slens.dev/

Run scripts:
1) **CreateResourcesInAzure.ps1**
This script will create: 
- ACR for docker images and Helm charts, generate AcrSettings.ps1 for the next script
- AKS (Kubernetes instance) for the application and DB, generate "kubeconfig" for the next script and Lens
2) **CreateImagesAndRunInKubernetes.ps1**
This script will:
- Build and upload API and UI images to ACR
- Build and upload Helm Chart to ACR
- Run instance of the application in Kubernetes
3) **helmChartTemplate** folder 
Helm Chart for the application

As a result you will get Kubernetes instance with One Discovery demo inside. 
Run the following command in CICD folder to get external ip:
`$services = (kubectl get services --namespace=onediscoverydemo --kubeconfig kubeconfig -o json | ConvertFrom-Json)`
`($services.items | Where-Object {$_.metadata.name -Match "one-discovery-demo-ui-loadbalancer"} | Select-Object -First 1).status.loadBalancer.ingress[0].ip`
put it to your hosts as 
`xx.xx.xx.xx onediscoverydemo.akerchin.site`
and open the https://onediscoverydemo.akerchin.site in a browser.

##### sampleDataForUpload.json
Just sample file with data to upload via UI.

### _Database_
We suggest to use ClickHouse.
##### Why Clickhouse
Clickhouse is an open-source column-oriented database management system that allows generating analytical data reports in real-time. 
1)	It manages extremely large volumes of data in a stable and sustainable manner. 
It’s easy to insert hundreds of millions of rows in a small period of time even with a pure hardware.
So, it should allow easily onboard the new clients. 
2)	The data stored by column rather than by row, it uses LZ4 to compress the data. Its possible to use ZSTD to save even more space. Clickhouse is able to compress the data far better than a row-oriented database like MS SQL. In case when you have 1 Tb database in MS SQL it will take less than 200 Gb to store the same data in Clickhouse. 
3)	Clickhouse is about 250x faster than MS SQL on an analytical query on a dataset with 10M records. Sure, it’s not a silver bullet, with its a great choice for BigData projects without complicated relations and minimal updates.
4) It's free & opensource (Apache License 2.0). 
5)	Clickhouse is used by Cloudflare, Bloomberg, eBay, Spotify, CERN, and 100s more companies in production. Yandex, for example, has multiple Clickhouse clusters with data of over 120 trillion rows and worth over 100 PiB. This shows how serious the companies are in adopting Clickhouse.

It should be a good choice for One Discovery project as we have pretty huge amounts of data, at the same time we have just a few tables without complicated relations and the main scenario is "insert", we add the new documents, in common case we aren't modify/delete them. 
##### Limitations
1)	Clickhouse is not built to handle row updates and deletions efficiently. 
2)	JOIN operation uses the hash join algorithm. Clickhouse takes the right_table and creates a hash table for it in RAM. So, memory limitations are possible in case if you join two huge tables.
3)	Prefers batch data insertion. Due to the nature of how the MergeTree engine works, it works best if you insert the data in large batches rather than small frequent insertions.

Documentation:
https://clickhouse.com/docs/en/getting-started


### _CI/CD_
We suggest to use Kubernetes.

##### Why Kubernetes
1) It can satisfy our needs. We require databases in different regions. From latency standpoint, for best performance, we should have API and DB in one region. Ideally, in one datacenter. Best option if we are able to use the same machine. Therefore, ideally if we put the API instances, which are working with DBs near the DBs. And that's a possible option with Azure AKS. Just run the AKS with all the stuff inside.
2) Microservices are a trend over the last many years. And Kubernetes is de facto standard here. Most new projects in 2022 starting with microservices. Most of the legacy projects are migrating to microservices, or at least they have such plans.
3) Cost management. Kubernetes is free. AKS Service is also free. You pay only for VMs, which Azure use for your cluster. We can reuse these VM for hosting the UI, API and DB. No need to buy different instances of Azure Web Apps. At the same time its still PaaS, therefore VMs configuration is not our pain.
4) In case if client needs to set up One Discovery instance inside his private network, it will not be a problem to set up the instance on Kubernetes on-premise. In common case it will work exactly the same way as in AKS. But in case if from privacy standpoint Azure is not applicable for the client, it will not be an issue at all.


### _Security_

In case of AKS usage, the only port, which opened outside will be HTTPS(443), port for UI/API. 
So security should not be an issue. 

Security concepts for applications and clusters in Azure Kubernetes Service (AKS):
https://docs.microsoft.com/en-us/azure/aks/concepts-security
Best practices for cluster security and upgrades in Azure Kubernetes Service (AKS):
https://docs.microsoft.com/en-us/azure/aks/operator-best-practices-cluster-security

### _Future Development & Features_
As soon One Discovery to integrate analytical search over the documents, its good idea to add ElasticSearch as a part of a separate microservice for search. 
For now its #1 as a Search engine in the world:  
https://db-engines.com/en/ranking
Elasticsearch allows you to store, search, and analyze huge volumes of data quickly and in near real-time and give back answers in milliseconds. It’s able to achieve fast search responses because instead of searching the text directly, it searches an index. It takes into account the morphology, language structure, particular qualities and it can create valid scoring/ranking for search.

Ky points of Elasticsearch
1. Scalability
2. Fast performance
3. Multilingual
4. Document oriented (JSON)
5. Auto-completion and instance search
6. Schema free

Documentation:
https://www.elastic.co/guide/en/elasticsearch/reference/8.0/docker.html



