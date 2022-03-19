using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using OneDiscoveryDemoApi.Models;

namespace OneDiscoveryDemoApi.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class DataController : ControllerBase
    {
        private static bool _isInitialized;
        private readonly MD5 _md5 = MD5.Create();
        private readonly ClickHouseDb _clickHouseDb;

        public DataController(ClickHouseDb clickHouseDb)
        {
            _clickHouseDb = clickHouseDb;
            if (!_isInitialized)
            {
                _isInitialized = true;
                _clickHouseDb.CreateDemoDb();
            }
        }

        [HttpGet("getrowstotal")]
        public IActionResult GetRowsTotal() => Ok(new {rowsTotal = _clickHouseDb.GetRowsTotal()});

        [HttpPost("search")]
        public IActionResult GetRowsTotal([FromBody]SearchTerm searchTerm) => Ok(_clickHouseDb.SearchInDemoDoc(searchTerm.Term, searchTerm.Field));

        [HttpPost("addrandomrows")]
        public async Task<IActionResult> AddRandomRows()
        {
            // generate 1 million of random rows 
            var now = DateTime.UtcNow;
            var uploadList = new List<object[]>();
            for (var i = 0; i < 1000000; i++)
            {
                var uniqueId = Guid.NewGuid().ToString();
                uploadList.Add(new object[]
                {
                    now,
                    uniqueId,
                    $"Desc for {uniqueId}",
                    GetHash(uniqueId),
                    new List<string> { $"{uniqueId}-tag1", $"{uniqueId}-tag2" },
                });
            }
            // add Collection with 1 million of random rows to DB 100 times
            for (var j = 0; j < 100; j++)
            {
                await _clickHouseDb.AddToDemoDoc(uploadList);
            }
            return NoContent();
        }

        [HttpPost("upload")]
        public async Task<IActionResult> PostFile(IFormFile uploadedFile)
        {
            if (uploadedFile != null)
            {
                // parse JSON file into Collection
                await using var memoryStream = new MemoryStream();
                uploadedFile.CopyToAsync(memoryStream).Wait();
                var jsonString = Encoding.Default.GetString(memoryStream.ToArray());
                var sampleList = JsonConvert.DeserializeObject<List<Row>>(jsonString);
                var now = DateTime.UtcNow;
                var uploadList = new List<object[]>();
                foreach (var sampleListItem in sampleList)
                {
                    uploadList.Add(new object[]
                    {
                        now,
                        sampleListItem.Name,
                        sampleListItem.Description,
                        GetHash(sampleListItem.Name),
                        sampleListItem.Tags,
                    });
                }
                // add Collection to DB
                await _clickHouseDb.AddToDemoDoc(uploadList);
            }
            return NoContent();
        }
       
        public string GetHash(string input) => Convert.ToBase64String(_md5.ComputeHash(Encoding.UTF8.GetBytes(input)));
    }
}
