import { Component } from '@angular/core';

@Component({
  selector: 'app-users',
  standalone: true,
  template: '<h1>Users</h1>',
  host: { 'data-testid': 'users-page' },
})
export class Users {}
