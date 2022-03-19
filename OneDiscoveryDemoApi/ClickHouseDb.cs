using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using ClickHouse.Client.ADO;
using ClickHouse.Client.Copy;
using ClickHouse.Client.Utility;
using Microsoft.Extensions.Configuration;
using OneDiscoveryDemoApi.Models;

namespace OneDiscoveryDemoApi
{
    public class ClickHouseDb
    {
        private readonly IConfiguration _configuration;
        private const string ConnectionStringVariableName = "ClickHouseConnectionString";
        public ClickHouseDb(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        private string DbConnStr => Environment.GetEnvironmentVariable(ConnectionStringVariableName.ToUpper()) ?? _configuration[ConnectionStringVariableName];

        public ulong GetRowsTotal()
        {
            using var connection = new ClickHouseConnection(DbConnStr);
            connection.Open();
            return (ulong)connection.ExecuteScalarAsync("SELECT count() FROM demo_doc").Result;
        }

        public void CreateDemoDb()
        {
            using var connection = new ClickHouseConnection(DbConnStr);
            connection.Open();
            var command = connection.CreateCommand();
            command.CommandText = "DROP TABLE IF EXISTS demo_doc";
            command.ExecuteNonQuery();
            command.CommandText = $@"
                CREATE TABLE demo_doc 
                (
                    d Date CODEC(ZSTD), 
                    name String CODEC(ZSTD), 
                    description String CODEC(ZSTD),
                    hash String CODEC(ZSTD), 
                    tags Array(String) CODEC(ZSTD),
                    INDEX hash_index (name) TYPE minmax GRANULARITY 4
                ) 
                ENGINE = MergeTree 
                PARTITION BY toYYYYMM(d) 
                ORDER BY hash 
                SETTINGS index_granularity = 8192";
            command.ExecuteNonQuery();
        }

        public async Task AddToDemoDoc(IEnumerable<object[]> uploadList)
        {
            await using var connection = new ClickHouseConnection(DbConnStr);
            using var bulkCopyInterface = new ClickHouseBulkCopy(connection)
            {
                DestinationTableName = "default.demo_doc",
                BatchSize = 1000000
            };

            await bulkCopyInterface.WriteToServerAsync(uploadList);
            Console.WriteLine(bulkCopyInterface.RowsWritten);
        }

        public List<Row> SearchInDemoDoc(string term, string field)
        {
            var result = new List<Row>();
            using var connection = new ClickHouseConnection(DbConnStr);
            connection.Open();
            var searchExpression = "=";
            if (term.Contains("*"))
            {
                searchExpression = "like";
                term = term.Replace("*", "%");
            }

            var whereExpression = string.Empty;
            if (field == "tags")
            {
                whereExpression = $"WHERE arrayExists( tag -> (tag {searchExpression} '{term}') , tags)";
            }
            else if (term != "*")
            {
                whereExpression = $"WHERE {field} {searchExpression} '{term}'";
            }

            var command = connection.CreateCommand();
            command.CommandText = $@"
                SELECT 
                        name, 
                        description, 
                        hash, 
                        tags 
                    FROM 
                        demo_doc 
                    {whereExpression} 
                    LIMIT 100";
            var reader = command.ExecuteReader();
            do
            {
                while (reader.Read())
                {
                    result.Add(new Row
                    {
                        Name = (string)reader["name"],
                        Description = (string)reader["description"],
                        Hash = (string)reader["hash"],
                        Tags = ((string[])reader["tags"]).ToList()
                    });
                }
            } while (reader.NextResult());
            reader.Close();
            return result;
        }
    }
}
