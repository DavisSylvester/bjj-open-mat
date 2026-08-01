import { Component } from '@angular/core';

@Component({
  selector: 'app-gyms',
  standalone: true,
  template: '<h1>Gyms</h1>',
  host: { 'data-testid': 'gyms-page' },
})
export class Gyms {}
