import { Component } from '@angular/core';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  template: '<h1>Dashboard</h1>',
  host: { 'data-testid': 'dashboard-page' },
})
export class Dashboard {}
