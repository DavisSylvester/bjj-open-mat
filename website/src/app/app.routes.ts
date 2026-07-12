import { Routes } from '@angular/router';
import { Landing } from './landing/landing';
import { RegisterGym } from './pages/register-gym/register-gym';

export const routes: Routes = [
  { path: '', component: Landing },
  { path: 'register-gym', component: RegisterGym },
];
