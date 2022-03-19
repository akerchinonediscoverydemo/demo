using System.Collections.Generic;

namespace OneDiscoveryDemoApi.Models
{
    public class Row
    {
        public string Name { get; set; }
        public string Hash { get; set; }
        public string Description { get; set; }
        public List<string> Tags { get; set; }
    }
}
