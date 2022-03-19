import { HttpClient } from '@angular/common/http';
import { Component } from '@angular/core';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent {
  displayedColumns: string[] = ['name', 'description', 'hash', 'tags'];
  dataSource: PeriodicElement[] = [];
  searchValue = '*';
  field = 'name';
  fileName = '';
  rowsTotal: number = 0;
  timeLeft: number = 3;
  interval: any;

  constructor(private http: HttpClient) {
    this.startTimer();
  }

  startTimer() {
    this.interval = setInterval(() => {
      if (this.timeLeft > 0) {
        this.timeLeft--;
      } else {
        this.getRowsTotal();
        this.timeLeft = 3;
      }
    },1000)
  }
  
  getRowsTotal(){
    this.http.get("/api/data/getrowstotal").subscribe(
      (data: any) => {this.rowsTotal = data.rowsTotal; }
    );
  }

  searchTerm(term: string, field: string){
    this.http.post("/api/data/search", {term: term, field: field}).subscribe(
      (data: any) => {this.dataSource = data; }
    );
  }

  addRandomRows() {
    this.http.post("/api/data/addrandomrows", '').subscribe();
  }

  onFileSelected(event: any) {
    const file:File = event.target.files[0];
    if (file) {
      this.fileName = file.name;
      const formData = new FormData();
      formData.append("uploadedFile", file);
      this.http.post("/api/data/upload", formData).subscribe();
    }
  }
}

export interface PeriodicElement {
  name: string;
  hash: string;
  description: string;
  tags: string[];
}
