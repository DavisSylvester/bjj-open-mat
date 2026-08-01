import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./features/dashboard/dashboard').then((m) => m.Dashboard),
  },
  {
    path: 'users',
    loadComponent: () =>
      import('./features/users/users').then((m) => m.Users),
  },
  {
    path: 'gyms',
    loadComponent: () =>
      import('./features/gyms/gyms').then((m) => m.Gyms),
  },
  {
    path: 'open-mats',
    loadComponent: () =>
      import('./features/open-mats/open-mats').then((m) => m.OpenMats),
  },
  {
    path: 'members',
    loadComponent: () =>
      import('./features/members/members').then((m) => m.Members),
  },
  {
    path: 'schedules',
    loadComponent: () =>
      import('./features/schedules/schedules').then((m) => m.Schedules),
  },
];
